import gleam/option.{type Option, unwrap}

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
      <> unwrap(username, "")
      <> ":"
      <> unwrap(password, "")
      <> "@"
      <> unwrap(hostname, "")
      <> "/"
      <> unwrap(database, "")
    }
    MySql -> {
      "mysql://"
      <> unwrap(username, "")
      <> ":"
      <> unwrap(password, "")
      <> "@"
      <> unwrap(hostname, "")
      <> "/"
      <> unwrap(database, "")
    }
    Postgres -> {
      "postgresql://"
      <> unwrap(username, "")
      <> ":"
      <> unwrap(password, "")
      <> "@"
      <> unwrap(hostname, "")
      <> "/"
      <> unwrap(database, "")
    }
    LibSql -> {
      "libsql://"
      <> unwrap(database, "")
      <> ".turso.io?authToken="
      <> unwrap(password, "")
    }
    SqlLite -> {
      "sqlite:///" <> unwrap(hostname, "")
    }
  }
}
