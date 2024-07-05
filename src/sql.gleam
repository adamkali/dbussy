import gleam/option.{type Option, unwrap}
import gleam/uri
import errors.{type DbussyError}

pub type Sql {
  None
  MSSql
  MySql
  Postgres
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
      "sqlite:///"
      <> uri.percent_encode(unwrap(hostname, ""))
    }
  }
}

//pub fn connect() -> Result()

pub fn from_string(in:String) -> Result(Sql, errors.DbussyError) {
    case in {
         "mssql" -> Ok(new_mssql())
         "libsql" ->   Ok(new_libsql())
         "mysql" ->    Ok(new_mysql())
         "sqlite" ->   Ok(new_sqllite())
         "postgres" -> Ok(new_postgres())
         _ -> Error(errors.sql_error("Not a recognized engine"))
    }
}
