import gleam/bytes_builder
import gleam/dynamic.{type Dynamic, field, list, optional, string}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/otp/actor
import gleam/string_builder
import glisten.{Packet}
import sql

pub fn main() {
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      let assert Packet(msg) = msg
      let assert Ok(_) = glisten.send(conn, deserialize(msg))
      actor.continue(state)
    })
    |> glisten.serve(8987)
  process.sleep_forever()
}

pub type DbussyError {
  DeserializeError(msg: String)
}

pub fn deserialize(msg: BitArray) -> bytes_builder.BytesBuilder {
  let assert Ok(command) = json.decode_bits(msg, command_request_de())
  let CommandRequest(cmd, args) = command
  case cmd {
    "ping" -> execute_command(cmd: Ping)
    "selectTop100" -> {
      new_select_top_100()
      |> compile(option.unwrap(args, or: list.new()))
      |> parse_args()
      |> execute_command()
    }
    "connect" -> {
      new_connect()
      |> compile(option.unwrap(args, or: list.new()))
      |> execute_command()
    }
    _ -> execute_command(cmd: CommandError("Oops :)"))
  }
}

pub fn execute_command(
  cmd parsed_command: Command,
) -> bytes_builder.BytesBuilder {
  case parsed_command {
    NewCommand -> {
      panic as "This should never happen"
    }
    Ping -> {
      bytes_builder.from_string("Pong")
    }
    SelectTop100(_, result_command) -> {
      bytes_builder.from_string(result_command)
    }
    Connect(_, _, _, _, _, result_command) -> {
      bytes_builder.from_string(result_command)
    }
    CommandError(e) -> {
      io.debug(e)
      bytes_builder.from_string("[Error]\t" <> e)
    }
  }
}

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
  SelectTop100(table: String, result_command: String)
  CommandError(String)
}

pub fn new_select_top_100() -> Command {
  SelectTop100(table: "", result_command: "")
}

pub fn new_connect() -> Command {
  Connect(sql.None, option.None, option.None, option.None, option.None, "")
}

pub fn stringify_cmd(cmd: Command) -> String {
  case cmd {
    Connect(_, _, _, _, _, _) -> "Connect"
    SelectTop100(_t, _) -> "SelectTop100"
    NewCommand -> "NewCommand"
    Ping -> "Ping"
    CommandError(_s) -> "CommandError"
  }
}

pub fn new_command() -> Command {
  NewCommand
}

pub type CommandRequest {
  CommandRequest(cmd: String, args: Option(List(CommandRequestArgs)))
}

pub type CommandRequestArgs {
  CommandRequestArgs(key: String, val: String)
}

pub fn command_request_de() -> fn(Dynamic) ->
  Result(CommandRequest, List(dynamic.DecodeError)) {
  dynamic.decode2(
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
  )
}

pub fn parse_args(cmd: Command) -> Command {
  case cmd {
    SelectTop100(table, _) -> {
      let proposed_command = "SELECT * FROM"
      let post_proposed_command = "LIMIT 100"
      io.debug(table)
      SelectTop100(
        table: table,
        result_command: proposed_command
          <> " "
          <> table
          <> " "
          <> post_proposed_command,
      )
    }
    CommandError(s) -> CommandError(s)
    _ ->
      CommandError(
        "Could not parse args. Command<"
        <> stringify_cmd(cmd)
        <> "> does not have args to be parsed into. Panicing",
      )
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

pub fn compile(cmd: Command, args: List(CommandRequestArgs)) -> Command {
  case cmd {
    SelectTop100(_, _) -> {
      case list.length(args) {
        1 -> {
          let assert Ok(argument) = list.first(args)
          case argument.key {
            "table" -> {
              SelectTop100(argument.val, "")
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
    Connect(_, _, _, _, _, _) -> {
      case list.length(args) {
         2 -> { todo } 
         3 -> { todo }
         5 -> { todo }
        a -> compile_error_incorrect_args(cmd, a, args)
        
        
      }
    }
    _ -> cmd
  }
}
