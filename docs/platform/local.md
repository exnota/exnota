# Local

## Troubleshooting

### Port 3000 already in use, in dev container

A hypothesis of the cause: Saving changes while a request is in progress. Hot reload might not be able to kill the process while the request is in progress.

1. Inside the dev container, install netstat

   ```bash
   apt install net-tools
   ```

2. Find the PID (far right column,

   ```bash
   netstat -tulpn | grep ':3000'

   # E.g. where PID is 2606:
   #
   # tcp6   0  0   :::3000   :::*   LISTEN   2606/node
   ```

3. Kill it

   ```bash
   kill <pid>
   
   # E.g.
   # kill 2606
   ```
