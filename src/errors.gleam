pub type DbussyError {
  DeserializeError(msg: String)
  RPCError(msg: String)
  SqlError(msg: String)
  SerializeError(msg: String)
}

pub fn deserialize_error(msg message: String) -> DbussyError {
  DeserializeError(message)
}

pub fn serialize_error(msg message: String) -> DbussyError {
  DeserializeError(message)
}

pub fn rpc_error(msg message: String) -> DbussyError {
  RPCError(message)
}

pub fn sql_error(msg message: String) -> DbussyError {
  SqlError(message)
}


