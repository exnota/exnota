# Environment

## Local

* Use VS Code dev container
* Run from `/workspaces/exnota/app/backend`
  * Note: `/pb` will still be created as per production but should not be used for development
* Run `./start-dev.sh`
* To test a production build, run `./build.sh` and `./start.sh`
  * These should NOT run from `/pb`, but instead the workspace file above

## Prod

* Use docker
* Runs from `/pb`
* Needs volume set to `/pb/pb_data`
  * Options
    1. Use `docker compose`. Already configured in `docker-compose.ytml`
    2. Use volume commands when executing `docker`
