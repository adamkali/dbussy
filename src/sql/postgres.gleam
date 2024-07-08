import gleam/dynamic.{type Dynamic}
import gleam/io
import gleam/int
import gleam/option.{type Option}
import gleam/pgo.{type Connection, type QueryError}

pub fn connect(
  host hostname: Option(String),
  db database: Option(String),
  user username: Option(String),
  pass password: Option(String),
) -> Result(Connection, Nil) {
  let assert option.Some(hostname) = hostname
  let assert option.Some(username) = username
  let assert option.Some(database) = database
  io.debug(hostname)
  io.debug(username)
  io.debug(database)
  io.debug(password)
  let config =
    pgo.Config(
      ..pgo.default_config(),
      host: hostname,
      database: database,
      user: username,
      password: password,
    )
  let res = pgo.connect(config)
  io.debug(res)
  Ok(res)
}

pub type Table{
    Table(name: String)
}

pub fn get_schema(cnx: Connection) -> Result(pgo.Returned(String), String) {
  let query =
    "SELECT table_name
FROM information_schema.tables
WHERE table_type='BASE TABLE'
AND table_schema NOT IN ('pg_catalog', 'information_schema');"
  case pgo.execute(query, cnx, [], dynamic.element(0, dynamic.string)) {
    Ok(r) -> Ok(r)
    Error(err) -> Error(serialize_query_error(err))
  }
}

pub fn serialize_query_error(e: QueryError) -> String {
  case e {
    pgo.ConstraintViolated(msg, con, det) -> msg <> " " <> con <> " " <> det
    pgo.ConnectionUnavailable -> "Connection unavailable"
    pgo.UnexpectedArgumentCount(expected, got) ->
      "expected " <> int.to_string(expected) <> " got " <> int.to_string(got)
    pgo.UnexpectedResultType(_e) -> "Unexpected Result Type"
    pgo.UnexpectedArgumentType(expected, got) ->
      "expected " <> expected <> " got " <> got
    pgo.PostgresqlError(code, name, message) ->
      "[" <> code <> "] " <> name <> ": " <> message
  }
}
