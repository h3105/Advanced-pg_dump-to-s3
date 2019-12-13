#!/bin/bash

echo "Set current directory"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Import config file"
source ./pg_dump-to-s3.conf

# Vars
NOW=$(date +"%d%m%Y%H%M%S")

echo "split databases"
IFS=',' read -ra DBS <<< "$PG_DATABASES"

echo " * Backup in progress.,.";

echo "Loop thru databases"
for db in "${DBS[@]}"; do
    FILENAME="$db"


    echo "   -> backing up $db..."

    # Dump database
    pg_dump -Fc -w -h $PG_HOST -U $PG_USER -p $PG_PORT $db > /tmp/"$FILENAME".dump
    if [ ! "$?" = 0 ]; then
        echo "DB-Connection didn't work... Aborting."
        exit
    fi

    # Copy to S3
    s3cmd put /tmp/"$FILENAME".dump s3://$S3_PATH"_"$NOW/"$FILENAME".dump --storage-class STANDARD_IA

    # Delete local file
    rm /tmp/"$FILENAME".dump

    # Log
    echo "      ...database $db has been backed up"
done

echo ""
echo "...done!";
echo ""
