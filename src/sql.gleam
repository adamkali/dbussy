import errors.{type DbussyError}
import gleam/dynamic.{type Dynamic}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, unwrap}
import gleam/pgo.{type Connection}
import gleam/string_builder.{type StringBuilder}
import gleam/uri
import sql/postgres.{type Types as PT, PostgresColumnDeserializer}

pub type Sql {
  None
  MSSql
  MySql
  Postgres
  PostgresConnected(cnx: Connection)
  SqlLite
  LibSql
}

pub type Cnx {
  PostgesCnx(cnx: Connection)
}

pub type ReturnMember {
  ColSchema(name: String, typeof: String, limit: Option(Int))
}

pub type Returns {
  TableSchema(name: String, items: List(ReturnMember))
}

pub fn new_mssql() -> Sql {
  MSSql
}

pub fn new_mysql() -> Sql {
  MySql
}

pub fn new_postgres() -> Sql {
  Postgres
}

pub fn new_sqllite() -> Sql {
  SqlLite
}

pub fn new_libsql() -> Sql {
  LibSql
}

pub type ColumnDeserializer {
  PostgresColumnDeserializer(
    de: fn(Dynamic) -> Result(Dynamic, dynamic.DecodeError),
  )
}

pub type Types {
  PostgresTypes(t: PT)
}

pub fn connect_string(
  sql engine: Sql,
  host hostname: Option(String),
  db database: Option(String),
  uname username: Option(String),
  pword password: Option(String),
) -> String {
  case engine {
    None -> {
      panic as "None engine is impossible please check configuration"
    }
    MSSql -> {
      "mssql://"
      <> uri.percent_encode(unwrap(username, ""))
      <> ":"
      <> uri.percent_encode(unwrap(password, ""))
      <> "@"
      <> uri.percent_encode(unwrap(hostname, ""))
      <> "/"
      <> uri.percent_encode(unwrap(database, ""))
    }
    MySql -> {
      "mysql://"
      <> uri.percent_encode(unwrap(username, ""))
      <> ":"
      <> uri.percent_encode(unwrap(password, ""))
      <> "@"
      <> uri.percent_encode(unwrap(hostname, ""))
      <> "/"
      <> uri.percent_encode(unwrap(database, ""))
    }
    Postgres -> {
      "postgresql://"
      <> uri.percent_encode(unwrap(username, ""))
      <> ":"
      <> uri.percent_encode(unwrap(password, ""))
      <> "@"
      <> uri.percent_encode(unwrap(hostname, ""))
      <> "/"
      <> uri.percent_encode(unwrap(database, ""))
    }
    LibSql -> {
      "libsql://"
      <> uri.percent_encode(unwrap(database, ""))
      <> ".turso.io?authToken="
      <> uri.percent_encode(unwrap(password, ""))
    }
    SqlLite -> {
      "sqlite:///" <> uri.percent_encode(unwrap(hostname, ""))
    }
    _ -> ":)"
  }
}

pub fn print(sql engine: Sql) -> String {
  case engine {
    Postgres -> io.debug("Postgres")
    PostgresConnected(_) -> io.debug("Postgres Connected")
    MySql -> io.debug("MySql")
    MSSql -> io.debug("MsSql")
    LibSql -> io.debug("LibSql")
    SqlLite -> io.debug("SqlLite")
    None -> io.debug("None")
  }
}

pub fn connect(
  sql engine: Sql,
  host hostname: Option(String),
  db database: Option(String),
  uname username: Option(String),
  pword password: Option(String),
) -> Result(Sql, errors.DbussyError) {
  case engine {
    None ->
      Error(errors.sql_error("Connect message never sent cannot continue..."))
    LibSql -> Error(errors.sql_error("I did not implement this: LibSql"))
    MSSql -> Error(errors.sql_error("I did not implement this: MSSql"))
    MySql -> Error(errors.sql_error("I did not implement this: MySql"))
    Postgres -> {
      case
        postgres.connect(
          host: hostname,
          db: database,
          user: username,
          pass: password,
        )
      {
        Ok(ctx) -> {
          Ok(PostgresConnected(ctx))
        }
        Error(_) -> {
          Error(errors.sql_error("Could not connect to the database"))
        }
      }
    }
    SqlLite -> Error(errors.sql_error("I did not implement this"))
    PostgresConnected(cnx) -> Ok(PostgresConnected(cnx))
  }
}

pub fn from_string(in: String) -> Result(Sql, errors.DbussyError) {
  case in {
    "mssql" -> Ok(new_mssql())
    "libsql" -> Ok(new_libsql())
    "mysql" -> Ok(new_mysql())
    "sqlite" -> Ok(new_sqllite())
    "postgres" -> Ok(new_postgres())
    _ -> Error(errors.sql_error("Not a recognized engine"))
  }
}

pub fn get_schema(sql engine: Sql) -> Result(StringBuilder, errors.DbussyError) {
  case engine {
    PostgresConnected(cnx) ->
      case postgres.get_schema(cnx) {
        // get the schemea for every row returned
        Ok(returned) -> {
          let new_list =
            list.try_map(returned.rows, fn(row: String) -> Result(
              Returns,
              errors.DbussyError,
            ) {
              case postgres.get_schema_table_cols_dynamic(cnx, row) {
                Ok(returned) -> {
                  let columns =
                    list.map(
                      returned.rows,
                      fn(r: #(String, String, Option(Int))) -> ReturnMember {
                        ColSchema(r.0, r.1, r.2)
                      },
                    )
                  Ok(TableSchema(row, columns))
                }
                Error(str) -> {
                  "table_col_schema" |> io.debug
                  Error(errors.sql_error(str))
                }
              }
            })
          case new_list {
            Ok(result) -> {
              Ok(
                json.object([
                  #(
                    "response",
                    json.array(result, fn(result_item: Returns) -> json.Json {
                      let TableSchema(table_name, cols) = result_item
                      json.object([
                        #("table", json.string(table_name)),
                        #(
                          "schema",
                          json.array(
                            from: cols,
                            of: fn(a: ReturnMember) -> json.Json {
                              json.object([
                                #("col_name", json.string(a.name)),
                                #("col_type", json.string(a.typeof)),
                                #("col_limit", json.nullable(a.limit, json.int)),
                              ])
                            },
                          ),
                        ),
                      ])
                    }),
                  ),
                ])
                |> json.to_string_builder(),
              )
            }
            Error(errors) -> Error(errors)
          }
        }
        Error(s) -> {
          io.debug(s)
          Error(errors.sql_error(s))
        }
      }
    Postgres -> {
      Error(errors.sql_error("sql.postgres.connect() was not called"))
    }
    _ -> todo
  }
}

pub fn column(
  sql: Sql,
  name col_name: String,
  typeof col_type: String,
) -> Result(#(String, Types), DbussyError) {
  case sql {
    PostgresConnected(_) -> {
      case postgres.parse_type(col_type) {
        Ok(ty) -> Ok(#(col_name, PostgresTypes(ty)))
        Error(e) -> Error(errors.rpc_error(e))
      }
    }
    _ -> Error(errors.rpc_error("i dont know man"))
  }
}

pub fn select_top_100(
  sql engine: Sql,
  table table_name: String,
  cols col_defs: List(#(String, String)),
) -> Result(StringBuilder, errors.DbussyError) {
  case engine {
    PostgresConnected(cnx) -> {
// # make this work at all costs
      let col_defs_parsed =
        list.try_map(col_defs, fn(col: #(String, String)) -> Result(
          #(String, Types),
          errors.DbussyError,
        ) {
            column(engine, col.0, col.1)
        })
      case postgres.select_top_100(cnx, table: table_name) {
        Ok(result_core) -> {
          io.debug(result_core)
          Ok(string_builder.from_string("hi"))
        }
        Error(error) -> Error(errors.sql_error(error))
      }
    }
    _ -> panic as "You do not have the right"
  }
}

pub fn sql_to_cnx(sql sql_config: Sql) -> Result(Cnx, DbussyError) {
  case sql_config {
    PostgresConnected(cnx) -> Ok(PostgesCnx(cnx: cnx))
    _ ->
      Error(errors.rpc_error(
        "Internal error occured passing around the connection",
      ))
  }
}

pub fn cnx_to_sql(cnx: Cnx) -> Result(Sql, DbussyError) {
  case cnx {
    PostgesCnx(cnx) -> Ok(PostgresConnected(cnx))
  }
}
