import gleam/bytes_builder
import gleam/http
import gleam/http/elli
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleamyshell
import simplifile

pub fn get_wav_from_mp3_file(rnd: String, file: String) {
  let _ =
    gleamyshell.execute("ffmpeg", "./" <> rnd, [
      "-hide_banner",
      "-loglevel",
      "error",
      "-i",
      file,
      "-ac",
      "1",
      "-c:a",
      "dfpwm",
      "output.dfpwm",
    ])

  let assert Ok(bits) = simplifile.read_bits("./" <> rnd <> "/output.dfpwm")
  bits
}

fn get_song(song_name: String) {
  let rnd = int.random(2048) |> int.to_string()
  let _ = simplifile.create_directory(rnd)

  let _ =
    gleamyshell.execute("yt-dlp", "./" <> rnd, [
      "-q",
      "-f",
      "bestaudio",
      "-x",
      "--audio-format",
      "mp3",
      "--audio-quality",
      "0",
      "ytsearch:" <> song_name,
    ])

  case simplifile.read_directory(rnd) {
    Ok([mp3]) -> {
      let wav = get_wav_from_mp3_file(rnd, mp3)
      let _ = simplifile.delete(rnd)
      Ok(wav)
    }
    _ -> {
      let _ = simplifile.delete(rnd)
      Error(Nil)
    }
  }
}

fn service(
  req: request.Request(BitArray),
) -> response.Response(bytes_builder.BytesBuilder) {
  let assert http.Get = req.method

  let assert Ok(queries) =
    req
    |> request.get_query

  let assert Ok(song_name) =
    queries
    |> list.key_find("song")
    |> io.debug

  case get_song(string.trim(song_name)) {
    Ok(bits) -> {
      response.new(200)
      |> response.set_header("content-type", "octet/stream")
      |> response.set_body(bits |> bytes_builder.from_bit_array)
    }
    _ ->
      response.new(400)
      |> response.set_body(bytes_builder.new())
  }
}

pub fn main() {
  elli.become(service, 3000)
}
