#!/bin/bash

set -e

# Set current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import config file
source $DIR/pg_dump-to-s3.conf

# Vars
NOW=$(date +"%Y-%m-%d-at-%H-%M-%S")
DELETETION_TIMESTAMP=`[ "$(uname)" = Linux ] && date +%s --date="-$DELETE_AFTER"` # Maximum date (will delete all files older than this date)

# Split databases
IFS=',' read -ra DBS <<< "$PG_DATABASES"

echo " * Backup in progress.,.";

# Loop thru databases
for db in "${DBS[@]}"; do
    FILENAME="$NOW"_"$db"


    echo "   -> backing up $db..."

    # Dump database
    pg_dump -Fc -h $PG_HOST -U $PG_USER -p $PG_PORT $db > /tmp/"$FILENAME".dump

    # Copy to S3
    s3cmd put /tmp/"$FILENAME".dump s3://$S3_PATH/"$FILENAME".dump --storage-class STANDARD_IA

    # Delete local file
    rm /tmp/"$FILENAME".dump

    # Log
    echo "      ...database $db has been backed up"
done

# Delete old files
echo " * Deleting old backups...";

# Loop thru files
s3cmd ls s3://$S3_PATH/ | while read -r line;  do
    # Get file creation date
    createDate=`echo $line|awk {'print $1" "$2'}`
    createDate=`date -d"$createDate" +%s`

    if [[ $createDate -lt $DELETETION_TIMESTAMP ]]
    then
        # Get file name
        FILENAME=`echo $line|awk {'print $4'}`
        if [[ $FILENAME != "" ]]
          then
            echo "   -> Deleting $FILENAME"
            s3cmd rm s3://$S3_PATH/$FILENAME
        fi
    fi
done;

echo ""
echo "...done!";
echo ""
