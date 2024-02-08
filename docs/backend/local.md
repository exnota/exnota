# Local

## Run in dev mode

1. Use VS Code dev container
   1. Command: `Dev Containers: Open Workspace in Container`
   2. Select `backend.code-workspace`

     This runs `Dockerfile` in dev mode using `"target": "dev"` in `.devcontainer`
2. Run from `/workspaces/exnota/app/backend`
3. Run `Backend` VS Code launch config or `.tool/script/start-dev.sh`

## Run in prod mode

1. Use VS Code dev container
2. Run `./tool/script/build.sh` then `./tool/script/start.sh`

## Run the entire prod Docker container

1. Build `docker build --target prod --tag backend:prod .`
2. Run `docker run --name backend -p 8080:8080 --volume ./pb_data:/pb/pb_data -d backend:prod`

To rebuild and restart:

1. `docker stop backend` and `docker remove backend`
2. Repeat 1. and 2.

To restart:

* `docker restart backend`
* Or if already stopped: `docker start backend`

## Troubleshooting


### Workspace
* Don't add folders to workspace, e.g. `docs`
  * Dev Containers doesn't seem to support multiple. Sometimes it works, other times it seems to load `docs` instead of `backend` and doesn't start the docker container.