# ------------------------------
# Whisper build
#
# Builds whisper and downloads the models.
# ------------------------------
FROM debian:11 AS whisper-build

RUN apt-get update \
    && apt-get install -y libsdl2-dev alsa-utils g++ make wget

# whisper.cpp vs 1.5.3
RUN mkdir /whisper && \
    wget -q https://github.com/ggerganov/whisper.cpp/tarball/9962371f71b91fd236e8af08db1e9e4b10a6c363 -O - | \
    tar -xz -C /whisper --strip-components 1

WORKDIR /whisper
RUN make main stream

# ------------------------------
# Base
# 
# Copies whisper and models; Common setup for dev and prod.
# ------------------------------
# Using golang as the base to simplify the prod/dev stage split. Have assumed the
# overhead is inconsequential.
FROM golang:1.21.6-bullseye AS base

RUN apt-get update \
    # Transcription dependencies
    && apt-get install -y libsdl2-dev alsa-utils \
    # Pocketbase dependencies
    && apt-get install -y ca-certificates \
    # This cleanup is apparently to reduce image sizes (I copied it from some
    # other Dockerfile). See https://stackoverflow.com/a/61990740. It could be
    # done on other apt(-get) updates in this file.
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# ffmpeg packages. ffmpg isn't available via apt-get
RUN apt update \
    && apt install -y ffmpeg

# Copy whisper build files and model download script
COPY --from=whisper-build /whisper/main /usr/local/bin/whisper
COPY --from=whisper-build /whisper/stream /usr/local/bin/stream
RUN mkdir -p /whisper/models
COPY --from=whisper-build "/whisper/models/download-ggml-model.sh" "/whisper/models/download-ggml-model.sh"

# ------------------------------
# Dev environment
# ------------------------------
FROM base AS dev

# Download model
WORKDIR /whisper
# Default to base in dev to greatly decrease download time. Other models can be
# downloaded inside the dev container using this same script.
RUN bash ./models/download-ggml-model.sh "base"

# Dependencies
RUN apt-get update \
    # curl used to download golangci-lint below
    && apt-get install -y curl \
    # This cleanup is apparently to reduce image sizes (I copied it from some
    # other Dockerfile). See https://stackoverflow.com/a/61990740. It could be
    # done on other apt(-get) updates in this file.
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN go install -v github.com/go-delve/delve/cmd/dlv@latest
RUN go install -v golang.org/x/tools/gopls@latest
RUN go install -v  honnef.co/go/tools/cmd/staticcheck@2023.1.6
# binary will be $(go env GOPATH)/bin/golangci-lint
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.55.2

EXPOSE 8080

# ------------------------------
# Prod environment
# ------------------------------
FROM base AS prod

# Download models
WORKDIR /whisper
RUN bash ./models/download-ggml-model.sh "large-v2"
RUN bash ./models/download-ggml-model.sh "large-v3"

WORKDIR /tmp/backend
# Copy host working directory to image working directory.
# Contents of .dockerignore will be excluded.
COPY . .
RUN ./tool/script/build.sh
# Move binary
RUN mkdir /pb
RUN mv backend /pb

EXPOSE 8080

WORKDIR /pb
# Keep command in sync with tool/script/start.sh
CMD ./backend serve --http=0.0.0.0:8080