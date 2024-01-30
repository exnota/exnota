FROM debian:11 AS build

RUN apt-get update \
    && apt-get install -y libsdl2-dev alsa-utils g++ make wget

# whisper.cpp vs 1.5.3
RUN mkdir /whisper && \
    wget -q https://github.com/ggerganov/whisper.cpp/tarball/9962371f71b91fd236e8af08db1e9e4b10a6c363 -O - | \
    tar -xz -C /whisper --strip-components 1

WORKDIR /whisper

RUN bash ./models/download-ggml-model.sh "large-v2"
RUN bash ./models/download-ggml-model.sh "large-v3"
RUN make main stream

FROM golang:1.21.6-bullseye AS whisper

# Transcription packages
RUN apt-get update \
    && apt-get install -y libsdl2-dev alsa-utils \
    # This cleanup is apparently to reduce image sizes (I copied it from some
    # other Dockerfile). See https://stackoverflow.com/a/61990740. It could be
    # done on other apt(-get) updates in this file.
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# ffmpeg packages. ffmpg isn't available via apt-get
RUN apt update \
    && apt install -y ffmpeg

# Transcription model
# WORKDIR /home/node

RUN mkdir -p /whisper/models
# RUN mkdir /whisper/audio
# RUN chown -R node /home/node/whisper 
# COPY --chown=node:node ./data/jfk.wav /home/node/whisper/audio
COPY --from=build "/whisper/models/ggml-large-v2.bin" "/whisper/models/ggml-large-v2.bin"
COPY --from=build "/whisper/models/ggml-large-v3.bin" "/whisper/models/ggml-large-v3.bin"
COPY --from=build /whisper/main /usr/local/bin/whisper
COPY --from=build /whisper/stream /usr/local/bin/stream

# Dev environment
# TODO: Put these in a separate build stage (https://docs.docker.com/build/building/multi-stage/)
# that is only used in dev environment: https://stackoverflow.com/a/60820156
RUN go install -v github.com/go-delve/delve/cmd/dlv@latest
RUN go install -v golang.org/x/tools/gopls@latest
RUN go install -v  honnef.co/go/tools/cmd/staticcheck@2023.1.6
# binary will be $(go env GOPATH)/bin/golangci-lint
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.55.2

# TODO: Update to 0.20.7
ARG PB_VERSION=0.20.6

RUN apt-get update \
    && apt-get install -y unzip ca-certificates curl

# copy app
# TODO: Don't do this in dev environment, where we work from the mounted
# /workspaces directory.
WORKDIR /pb
COPY go.mod go.sum main.go http.go build.sh start.sh ./
ADD migrations ./migrations

# Build app
# TODO: Don't do this in dev environment
RUN ./build.sh

EXPOSE 8080

# start PocketBase
CMD /pb/start.sh




# ENV HOST=0.0.0.0
# ENV PORT=3000

# USER node
# RUN mkdir /home/node/app
# WORKDIR /home/node/app

# COPY --chown=node:node package*.json ./
# RUN npm ci

# COPY --chown=node:node . .
# RUN npm run build 

# EXPOSE 3000

# CMD [ "node", "dist/main.js" ]
# USER root