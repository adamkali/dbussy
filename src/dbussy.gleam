import commands
import gleam/bytes_builder
import gleam/dynamic.{list}
import gleam/erlang/process
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/otp/actor
import glisten.{Packet}
import sql.{type Cnx}

pub fn main() {
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(None, None) }, fn(msg, state: Option(Cnx), conn) {
      let assert Packet(msg) = msg
      io.debug(msg)
      let consumed = consume(msg, state)
      let assert Ok(_) = glisten.send(conn, consumed.0)
      actor.continue(consumed.1)
    })
    |> glisten.serve(8987)
  process.sleep_forever()
}

pub fn consume(
  msg: BitArray,
  state: Option(Cnx)
) -> #(bytes_builder.BytesBuilder, option.Option(sql.Cnx)) {
  let assert Ok(command) = json.decode_bits(msg, commands.command_request_de())
  let commands.CommandRequest(cmd, args, defs) = command
  case cmd {
    "ping" -> commands.execute_command(cmd: commands.Ping)
    "selectTop100" -> {
      commands.new_select_top_100(state, defs)
      |> commands.compile(option.unwrap(args, or: list.new()))
      |> commands.parse_args()
      |> commands.execute_command()
    }
    "connect" -> {
      commands.new_connect()
      |> commands.compile(option.unwrap(args, or: list.new()))
      |> commands.parse_args()
      |> commands.execute_command()
    }
    _ -> {
      commands.execute_command(cmd: commands.CommandError("Oops :)"))
    }
  }
}

