FROM ghcr.io/gleam-lang/gleam:v1.5.1-erlang-alpine

# Latest version of yt-dlp
RUN wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/bin/yt-dlp
RUN chmod a+rx /usr/bin/yt-dlp

# dependencies
RUN apk add python3
RUN apk add ffmpeg

# App folder
RUN mkdir /app
COPY . /app
WORKDIR /app

# Compile
RUN gleam build

CMD [ "gleam", "run" ]