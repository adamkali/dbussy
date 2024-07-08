import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/pgo.{type Connection, type QueryError}
import gleam/string

pub fn connect(
  host hostname: Option(String),
  db database: Option(String),
  user username: Option(String),
  pass password: Option(String),
) -> Result(Connection, Nil) {
  let assert option.Some(hostname) = hostname
  let assert option.Some(username) = username
  let assert option.Some(database) = database
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

pub type Table {
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

pub fn get_schema_table_cols(
  cnx: Connection,
  table table_name: String,
) -> Result(pgo.Returned(#(String, String, Int)), String) {
  let query =
    "SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_name = $1;"
  case
    pgo.execute(
      query,
      cnx,
      [pgo.text(table_name)],
      dynamic.tuple3(
        dynamic.element(at: 0, of: dynamic.string),
        dynamic.element(at: 1, of: dynamic.string),
        dynamic.element(at: 2, of: dynamic.int),
      ),
    )
  {
    Ok(r) -> Ok(r)
    Error(err) -> Error(serialize_query_error(err))
  }
}

pub fn get_schema_table_cols_dynamic(
  cnx: Connection,
  table table_name: String,
) -> Result(pgo.Returned(#(String, String, dynamic.Dynamic)), String) {
  let query =
    "SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_name = $1;"
  case
    pgo.execute(
      query,
      cnx,
      [pgo.text(table_name)],
      dynamic.tuple3(
        dynamic.element(at: 0, of: dynamic.string),
        dynamic.element(at: 1, of: dynamic.string),
        dynamic.element(at: 2, of: dynamic.dynamic),
      ),
    )
  {
    Ok(r) -> {
      io.debug(r.rows)
      Ok(r)
    }
    Error(err) -> Error(serialize_query_error(err))
  }
}

pub fn serialize_query_error(e: QueryError) -> String {
  case e {
    pgo.ConstraintViolated(msg, con, det) -> msg <> " " <> con <> " " <> det
    pgo.ConnectionUnavailable -> "Connection unavailable"
    pgo.UnexpectedArgumentCount(expected, got) ->
      "expected " <> int.to_string(expected) <> " got " <> int.to_string(got)
    pgo.UnexpectedResultType(list) -> {
      let list_of_ls =
        list.map(list, fn(l) -> String {
          "expected: " <> l.expected <> " got: " <> l.found
        })
      string.join(["Unexpected Result type", ..list_of_ls], " ")
    }
    pgo.UnexpectedArgumentType(expected, got) ->
      "expected " <> expected <> " got " <> got
    pgo.PostgresqlError(code, name, message) ->
      "[" <> code <> "] " <> name <> ": " <> message
  }
}
