# Database

- [Database](#database)
  - [DBeaver tips](#dbeaver-tips)
  - [Connecting to prod](#connecting-to-prod)
  - [Setting up local database](#setting-up-local-database)
  - [Backup/restore manually via Dbeaver](#backuprestore-manually-via-dbeaver)
    - [Backup](#backup)
    - [Restore](#restore)

## DBeaver tips

- **You must use 'Commit'** in a 'Production' connection type
  - By default each command happens in a new transaction, so if you don't select
  'Commit' when you want to persist the change, it won't be saved.
  - Some changes require pressing 'Save', but that simply adds the command to
  the transaction, it doesn't commit the transaction.

## Connecting to prod

1. Download DBeaver ([link](https://dbeaver.io/download/))
2. Go to [Exnota Prod](https://dashboard.render.com/d/dpg-cmgshk7109ks73994o8g-a) in render
3. Select 'Connect', top right button
4. Select 'External Connection'
   1. Copy the URL
5. In the 'Connect to a database' wizard
   1. Select 'Postgresql'
   2. Select 'Connect by: URL'
   3. Paste the URL
   4. DBeaver requires a different format, make the following changes (to see the format, select 'Driver Settings')
      1. Add `jdbc:` at the start
      2. Change `postgres` to `postgresql`
      3. Cut `<username>:<password>@`
      4. Paste the username and password below in the relevant fields
   5. Configure more settings
      1. Select 'Connection details'
      2. For 'Connection name', set `exnota (prod)`
      3. For 'Connection type' select 'Production'
   6. Select 'Test Connection'. It will need to download drivers if this is the first time.
6. Select 'Finish'

## Setting up local database

1. Set the password
   1. Duplicate `tool/db/.env.template` to `tool/db/.env`
   2. Set a password in `.env`
2. Run
   1. In a terminal, go to `tool/db` then execute

      ```bash
      docker-compose up 
      ```

3. In DBeaver
   1. Create > Connection
   2. Postgresql
   3. Use settings:
      - Host: localhost (default)
      - Port: 5432 (default)
      - Database: **exnota** (same as `docker-compose.yml`)
      - Username: **exnota_user** (same as `docker-compose.yml`)
      - Password: **<what you entered in `.env`>**
   4. Configure more settings
      1. Select 'Connection details'
      2. For 'Connection name', set `exnota (prod)`
      3. For 'Connection type' select 'Development'
   5. Select 'Test Connection' to verify
   6. Select 'Finish'

## Backup/restore manually via Dbeaver

### Backup

A local Postgresql client is needed. This can be done using the steps in 'Setting up local database'.

1. Install libpq to help DBeaver automatically find the local client

   ```bash
   brew install libpq
   ```

2. In the `exnota (prod)` connection, right click the `exnota` database
3. Select Tools > Backup
   - Global backup doesn't work, likely because the managed render.com service has tables and other objects that we can't access.
4. Select all in 'Choose objects to export'.
5. In 'Backup settings' specify or note the output folder and filename.
6. Select 'Local Client'. It should automatically find it. Then select 'OK'.
7. Select 'Start'
8. When it's done, select 'Cancel'

### Restore

Note: Sometimes this process doesn't work when testing locally. Unsure what causes it. I've been able to get it work by closing DBeaver, trying again, etc. My hunch is that the Docker `postgres` is only intended to support one database, and if one takes to long with the below steps, the new database is deleted or becomes inaccessible. Maybe there's a better way to restore.

1. Select the target connection
2. Create a new database. Name something like `torestore`
3. Right click and set `torestore` as the default database
4. Close any tabs for the `exnota` database you have open
5. Delete the `exnota` database.
6. Right click `torestore` and select 'Tools' > 'Restore'. In the popup:
   1. Select the 'Backup file'
      - On MacOS you need to change the extension in the popup from `.backup` to `.sql`.
   2. Check the following
      - [x]  `Create database`
   3. Select 'Start'
7. You may see the following error, but it still seems to work

   ```bash
   pg_restore: error: could not execute query: ERROR:  schema "public" already exists
   ```
