# Deploy (prod)

- [How-to](#how-to)
  - [Steps](#steps)
  - [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
  - [Environment variables](#environment-variables)
  - [Checking logs](#checking-logs)
  - [How to execute Dokku commands](#how-to-execute-dokku-commands)
- [Initial setup](#initial-setup)
  - [SSH](#ssh)
  - [Dokku](#dokku)
- [Hetzner SSH](#hetzner-ssh)
  - [Terminal](#terminal)
  - [CLI](#cli)
- [Archive](#archive)
  - [Manual Hetzner deploy](#manual-hetzner-deploy)

## How-to

### Steps

Don't run inside dev container!

1. Setup (first time deploying from a device)
   - Ensure you have configured [SSH](#ssh)
   - Add Dokku remote to git repo

        ```bash
        # `exnota0` is the remote branch name, matching the app name
        git remote add dokku dokku@<domain>:exnota0
        ```

2. Deploy

    ```bash
    # Deploy master branch
    git push dokku main

    # Or: Deploy branch <branch-name>
    git push dokku <branch-name>:main
    ```

### Troubleshooting

#### Error: At least one invalid signature was encountered

Apparently caused by insufficient space according to this [SO post](https://stackoverflow.com/questions/62473932/at-least-one-invalid-signature-was-encountered) (which has more options for freeing space in addition to below).

Fix:

1. SSH to Hetzner server.
2. Run

    ```bash
    docker builder prune
    ```

## Maintenance

### Environment variables

See https://dokku.com/docs/configuration/environment-variables/

```bash
ssh -t dokku@195.201.33.178 config:get exnota0 VARIABLE_NAME
ssh -t dokku@195.201.33.178 config:get exnota0 VARIABLE_NAME=VALUE
```

### Checking logs

```bash
ssh -t dokku@195.201.33.178 logs exnota0 -t
```

### How to execute Dokku commands

There is an [official client](https://dokku.com/docs/deployment/remote-commands/#official-client) but commands can be executed simply via SSH:

1. Ensure SSH is setup as below.

2. Omit `dokku` root command and send sub-command.

    ```bash
        ssh -t dokku@195.201.33.178 <sub-command>

        # E.g. Send `dokku version`
        ssh -t dokku@195.201.33.178 version
    ```

## Initial setup

### SSH

1. Create an SSH key locally and add to Hetzner via UI.
   - This will be used for deploys and can be used to configure Dokku remotely.

### Dokku

1. Install Dokku and create app as per the official [installation](https://dokku.com/docs/getting-started/installation/) and [deployment](https://dokku.com/docs/deployment/application-deployment/) docs.
2. Set build directory

    ```bash
    dokku builder:set exnota0 build-dir app/backend
    ```

3. Set builder type to Docker and configure

    ```bash
    dokku builder:set exnota0 selected dockerfile

    # Set multi-stage build target
    dokku docker-options:add exnota0 build "--target prod"
    ```

4. Add domain (assuming its DNS config already points to VPS IP)

   ```bash
   dokku domains:add exnota0 <domain>
   ```

5. Remove default 'Welcome to nginx' page

    ```bash
    rm /etc/nginx/sites-enabled/default
    ```

6. Make app accessible without `8080` port:

    ```bash
    dokku ports:add exnota0 http:80:8080
    ```

7. Setup lets encrypt

    ```bash
    dokku letsencrypt:set exnota0 email email@mattschultz.info
    dokku letsencrypt:enable exnota0

    # Have not tested this. Unsure how to.
    dokku letsencrypt:cron-job --add
    ```

    It will give a warning like

    > Your account credentials have been saved in your Let's Encrypt configuration directory at "/certs/accounts".

    However the folder is actually empty. For now I have assumed this isn't
    actually necessary. Maybe Dokku handles it.
8. Setup volume for persistence

    ```bash
    # In the future should probably follow these steps INSTEAD of separate mkdir
    # and chown commands: https://dokku.com/docs/advanced-usage/persistent-storage/#creating-storage-directories

    mkdir -p /var/lib/dokku/data/storage/exnota0/pb_data

    chown dokku:dokku /var/lib/dokku/data/storage/exnota0/pb_data

    dokku docker-options:add exnota0 deploy "-v /var/lib/dokku/data/storage/exnota0/pb_data:/pb/pb_data"
    ```

## Hetzner SSH

### Terminal

```bash
% ssh root@195.201.33.178
Enter passphrase for key '/Users/matt/.ssh/id_ed25519_hetzner2':
```

### CLI

Have not logged in using CLI successfully yet. Maybe because of this ([link](https://docs.hetzner.com/cloud/servers/getting-started/vnc-console/)):

> If your server was created with an SSH key, or if you no longer have the password, you can request a new root password:

## Archive

Notes that may be useful in the future.

### Manual Hetzner deploy

1. Login as root (no other option for now)
2. mkdir deploy
3. Create ssh key to use as Github Deploy Key ([link](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys))
   - Ensure to also follow the Linux steps for 'Adding your SSH key to the ssh-agent'
4. Might need to manually add `~/.ssh/config` file
5. Clone. Which must be done via SSH not HTTPS (latter will ask for user/pass rather than use SSH Key)

    ```bash
    git clone -b pocketbase-poc git@github.com:mttschltz/exnota.git
    ```

6. cd exnota/app/backend
7. docker compose up
