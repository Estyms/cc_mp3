FROM ghcr.io/gleam-lang/gleam:v1.5.1-erlang-alpine

RUN apk add yt-dlp

RUN mkdir /app
COPY . /app

WORKDIR /app
RUN gleam build
CMD [ "gleam", "run" ]