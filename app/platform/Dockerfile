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

WORKDIR /home/node

ARG model=base
RUN mkdir -p /home/node/whisper/models
RUN mkdir /home/node/whisper/audio
RUN chown -R node /home/node/whisper 
COPY --chown=node:node ./data/jfk.wav /home/node/whisper/audio
COPY --from=build --chown=node:node "/whisper/models/ggml-${model}.bin" "/home/node/whisper/models/ggml-${model}.bin"
COPY --from=build --chown=node:node /whisper/main /usr/local/bin/whisper
COPY --from=build --chown=node:node /whisper/stream /usr/local/bin/stream

ENV HOST=0.0.0.0
ENV PORT=3000

RUN mkdir -p /tmp/upload/audio
RUN chown -R node /tmp/upload/audio
USER node
RUN mkdir /home/node/app
WORKDIR /home/node/app

COPY --chown=node:node package*.json ./
RUN npm ci

COPY --chown=node:node . .
RUN npm run build 

EXPOSE 3000

CMD [ "node", "dist/main.js" ]
