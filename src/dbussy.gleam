import commands
import gleam/bytes_builder
import gleam/dynamic.{list}
import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}
import gleam/io

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


pub fn deserialize(msg: BitArray) -> bytes_builder.BytesBuilder {
  let assert Ok(command) = json.decode_bits(msg, commands.command_request_de())
  let commands.CommandRequest(cmd, args) = command
  case cmd {
    "ping" -> commands.execute_command(cmd: commands.Ping)
    "selectTop100" -> {
      commands.new_select_top_100()
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
    _ -> commands.execute_command(cmd: commands.CommandError("Oops :)"))
  }
}
