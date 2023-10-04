FROM debian:11 AS build

RUN apt-get update \
    && apt-get install -y libsdl2-dev alsa-utils g++ make wget

RUN mkdir /whisper && \
    wget -q https://github.com/ggerganov/whisper.cpp/tarball/master -O - | \
    tar -xz -C /whisper --strip-components 1

WORKDIR /whisper

ARG model=base
RUN bash ./models/download-ggml-model.sh "${model}"
RUN make main stream

FROM node:18.18.0-bullseye AS whisper

RUN apt-get update \
    && apt-get install -y libsdl2-dev alsa-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root

ARG model=base
RUN mkdir /root/models
RUN mkdir /root/audio
COPY jfk.wav /root/audio
COPY --from=build "/whisper/models/ggml-${model}.bin" "/root/models/ggml-${model}.bin"
COPY --from=build /whisper/main /usr/local/bin/whisper
COPY --from=build /whisper/stream /usr/local/bin/stream