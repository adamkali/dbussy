import errors
import gleam/bytes_builder
import gleam/dynamic.{type Dynamic, field, list, optional, string}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/string_builder
import sql

// - [ ] TODO: need to change the CommandError to be a dbussy error to get that error managment at the deserialize error
// - [ ] and then spin up a new state into the actor

pub type Command {
  NewCommand
  Ping
  Connect(
    engine: sql.Sql,
    hostname: Option(String),
    database: Option(String),
    username: Option(String),
    password: Option(String),
    result_command: String,
  )
  SelectTop100(
    engine: sql.Sql,
    table: String,
    cols: ColDefs,
    result_command: String,
  )
  CommandError(String)
}

pub type ColDefs {
  ColDefs(cols: List(ColDef))
}

pub type ColDef {
  ColDef(col_name: String, col_type: String)
}

pub fn new_select_top_100(
  cnx: Option(sql.Cnx),
  defs: Option(List(ColDef)),
) -> Command {
  case cnx {
    Some(cnx) -> {
      case sql.cnx_to_sql(cnx) {
        Ok(cnx) ->
          case defs {
            Some(defs) ->
              SelectTop100(
                engine: cnx,
                table: "",
                cols: ColDefs(defs),
                result_command: "",
              )
            None -> panic as "Col defs must be past to do this"
          }
        Error(error) -> panic as error.msg
      }
    }
    None -> {
      panic as "You are not connected to a server. You do not have the right oh you do not have the right."
    }
  }
}

pub fn new_connect() -> Command {
  Connect(sql.None, option.None, option.None, option.None, option.None, "")
}

pub fn stringify_cmd(cmd: Command) -> String {
  case cmd {
    Connect(..) -> "connect"
    SelectTop100(..) -> "selectTop100"
    NewCommand -> "newCommand"
    Ping -> "ping"
    CommandError(_s) -> "commandError"
  }
}

pub fn new_command() -> Command {
  NewCommand
}

pub type CommandRequest {
  CommandRequest(
    cmd: String,
    args: Option(List(CommandRequestArgs)),
    defs: Option(List(ColDef)),
  )
}

pub type CommandRequestArgs {
  CommandRequestArgs(key: String, val: String)
}

pub fn command_request_de() -> fn(Dynamic) ->
  Result(CommandRequest, List(dynamic.DecodeError)) {
  dynamic.decode3(
    CommandRequest,
    field("cmd", of: string),
    field(
      "args",
      of: optional(
        list(dynamic.decode2(
          CommandRequestArgs,
          field("key", of: string),
          field("val", of: string),
        )),
      ),
    ),
    field(
      "col_defs",
      optional(
        dynamic.list(dynamic.decode2(
          ColDef,
          field("col_name", dynamic.string),
          field("col_type", dynamic.string),
        )),
      ),
    ),
  )
}

pub fn parse_args(cmd: Command) -> Command {
  case cmd {
    SelectTop100(sql, table, defs, ..) -> {
      let proposed_command = "SELECT * FROM"
      let post_proposed_command = "LIMIT 100"
      SelectTop100(
        sql,
        table: table,
        cols: defs,
        result_command: proposed_command
          <> " "
          <> table
          <> " "
          <> post_proposed_command,
      )
    }
    CommandError(s) -> CommandError(s)
    Connect(e, h, d, u, p, _) -> {
      Connect(e, h, d, u, p, sql.connect_string(e, h, d, u, p))
    }
    _ ->
      CommandError(
        "Could not parse args. Command<"
        <> stringify_cmd(cmd)
        <> "> does not have args to be parsed into. Panicing",
      )
  }
}

pub fn compile(cmd: Command, args: List(CommandRequestArgs)) -> Command {
  case cmd {
    SelectTop100(sql_connection, _table, defs, ..) -> {
      case list.length(args) {
        1 -> {
          let assert Ok(argument) = list.first(args)
          case argument.key {
            "table" -> {
              SelectTop100(sql_connection, argument.val, defs, "")
            }
            _ ->
              CommandError(
                "SelectTop100 argument key is something other than table: "
                <> argument.key,
              )
          }
        }
        a -> compile_error_incorrect_args(cmd, a, args)
      }
    }
    Connect(e, h, d, u, p, r) -> {
      let a = list.length(args)
      case int.compare(a, 6) {
        Lt -> {
          case args {
            [first, ..rest] -> {
              case first.key {
                "engine" -> {
                  let assert Ok(squeal) = sql.from_string(first.val)
                  compile(Connect(squeal, h, d, u, p, r), rest)
                }
                "hostname" -> {
                  compile(Connect(e, Some(first.val), d, u, p, r), rest)
                }
                "database" -> {
                  compile(Connect(e, h, Some(first.val), u, p, r), rest)
                }
                "username" -> {
                  compile(Connect(e, h, d, Some(first.val), p, r), rest)
                }
                "password" -> {
                  compile(Connect(e, h, d, u, Some(first.val), r), rest)
                }
                _ -> compile_unknown_connect_key(cmd, first)
              }
            }
            [] -> {
              Connect(e, h, d, u, p, "")
            }
          }
        }
        _ -> compile_error_incorrect_args(cmd, a, args)
      }
    }
    _ -> cmd
  }
}

pub fn compile_error_incorrect_args(
  tried: Command,
  length: Int,
  args: List(CommandRequestArgs),
) -> Command {
  let strings =
    list.map(args, fn(a: CommandRequestArgs) -> String {
      a.key <> ": " <> a.val <> ",\n"
    })
    |> string_builder.from_strings()
    |> string_builder.to_string()
  CommandError(
    "Args of length"
    <> int.to_string(length)
    <> "can not be used for "
    <> stringify_cmd(tried)
    <> ". Args passed\n"
    <> strings,
  )
}

pub fn compile_unknown_connect_key(
  tried: Command,
  bad: CommandRequestArgs,
) -> Command {
  CommandError(
    "...\n\""
    <> bad.key
    <> "\": \""
    <> bad.val
    <> "\",\n..."
    <> "can not be used for "
    <> stringify_cmd(tried),
  )
}

pub fn execute_command(
  cmd parsed_command: Command,
) -> #(bytes_builder.BytesBuilder, Option(sql.Cnx)) {
  case parsed_command {
    NewCommand -> {
      panic as "This should never happen"
    }
    Ping -> {
      let response =
        json.object([#("response", json.array(["pong"], json.string))])
        |> json.to_string_builder()
      #(bytes_builder.from_string_builder(response), option.None)
    }
    SelectTop100(sql, table, _, _) -> {
      let sql_response = sql.select_top_100(sql, table)
      case sql_response {
        Ok(response) -> {
          let response =
            json.object([
              #(
                "response",
                json.array([response |> string_builder.to_string], json.string),
              ),
            ])
            |> json.to_string_builder()
          #(bytes_builder.from_string_builder(response), option.None)
        }
        Error(sql_error) -> execute_command(CommandError(sql_error.msg))
      }
    }
    Connect(s, h, d, u, p, _result_command) -> {
      let ctx = sql.connect(s, h, d, u, p)
      case ctx {
        Ok(connected) -> {
          case sql.get_schema(connected) {
            Ok(serialized) -> {
              let cnx = sql.sql_to_cnx(connected)
              case cnx {
                Ok(cnx) -> {
                  #(
                    bytes_builder.from_string_builder(serialized),
                    option.Some(cnx),
                  )
                }
                Error(error) -> execute_command(CommandError(error.msg))
              }
            }
            Error(err) -> execute_command(CommandError(err.msg))
          }
        }
        Error(sql_error) -> execute_command(CommandError(sql_error.msg))
      }
    }
    CommandError(e) -> {
      io.debug(e)
      #(bytes_builder.from_string("[Error]\t" <> e), option.None)
    }
  }
}
