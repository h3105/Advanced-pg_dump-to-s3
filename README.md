# pg_dump-to-s3

Automatically dump and archive PostgreSQL backups to any s3 compatible sos

## Requirements

 - s3cmd


## Usage

```bash
./pg_to_s3.sh

## Restore a backup

```bash
pg_restore -d DB_NAME -Fc --clean PATH_TO_YOUR_DB_DUMP_FILE
```