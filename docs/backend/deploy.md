# Deploy (prod)

## Deploy to prod

1. Set up
   - SSH key
     - Create locally, outside of dev container, and add to Hetzner.
   - Git remote

        ```bash
        # `exnota0` is the remote branch name, matching the app name
        git remote add dokku dokku@<domain>:exnota0
        ```

2. Deploy

    ```bash
    # Deploy master branch
    git push dokku main

    # Deploy branch '<branch-name>' to remote 'master'
    git push dokku <branch-name>:master
    ```

## Initial setup

### Dokku on Hetzner

1. Install Dokku and create app as per the official [installation](https://dokku.com/docs/getting-started/installation/) and [deployment](https://dokku.com/docs/deployment/application-deployment/) docs.
2. Set build directory

    ```bash
    dokku builder:set <app-name> build-dir app/backend
    ```

3. Set builder type to Docker

    ```bash
    dokku builder:set <app-name> selected dockerfile
    ```

4. Add domain (assuming its DNS config already points to VPS IP)

   ```bash
   dokku domains:add <app-name> <domain>
   ```

5. Remove default 'Welcome to nginx' page

    ```bash
    rm /etc/nginx/sites-enabled/default
    ```

6. Make app accessible without `8080` port:

    ```bash
    dokku ports:add <app-name> http:80:8080
    ```

7. Setup lets encrypt

    ```bash
    dokku letsencrypt:set <app-name> email email@mattschultz.info
    dokku letsencrypt:enable <app-name>

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

    mkdir -p /var/lib/dokku/data/storage/<app-name>/pb_data

    chown dokku:dokku /var/lib/dokku/data/storage/<app-name>/pb_data

    dokku docker-options:add <app-name> deploy "-v /var/lib/dokku/data/storage/<app-name>/pb_data:/pb/pb_data"
    ```

### ~~Hetzner Manual Approach~~ (Replaced with Dokku above)

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
