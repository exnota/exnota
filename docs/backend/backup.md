# Backup

## SSL certificate

```bash
## Local machine

cd ~/Downloads/

scp -r root@195.201.33.178:/home/dokku/exnota0/letsencrypt/certs exnota-letsencrypt-backup

zip -r exnota-letsencrypt-backup-$(date -Iseconds).zip exnota-letsencrypt-backup
```

Then save

1. To BitWarden
   - As attachment to secure note: `Exnota Letsencrypt Backups`
2. And another destination
