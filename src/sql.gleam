import errors.{type DbussyError}
import gleam/dynamic
import gleam/io
import gleam/json
import gleam/option.{type Option, unwrap}
import gleam/pgo.{type Connection}
import gleam/uri
import sql/postgres

pub type Sql {
  None
  MSSql
  MySql
  Postgres
  PostgresConnected(cnx: Connection)
  SqlLite
  LibSql
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
      io.debug("Connect called")
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

pub fn get_schema(sql engine: Sql) -> Result(String, errors.DbussyError) {
  case engine {
    PostgresConnected(cnx) ->
      case postgres.get_schema(cnx) {
        // get the schemea for every row returned
        Ok(returned) -> {
          let result =
            json.object([
              #("count", json.int(returned.count)),
              #("rows", json.array(returned.rows, json.string)),
            ])
            |> json.to_string
          Ok(result)
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
