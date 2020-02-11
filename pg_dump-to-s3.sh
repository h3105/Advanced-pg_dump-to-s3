#!/bin/bash

############################### FUNCTIONS
# Delete local file
delfiles()
{
    rm /tmp/"$FILENAME".dump
}

###########################################

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
        touch ./.db.ERROR
        exit
    fi

    # Copy to S3
    s3cmd put /tmp/"$FILENAME".dump s3://$S3_PATH/"dump_"$NOW/"$FILENAME".dump --storage-class STANDARD_IA
    if [ ! "$?" = 0 ]; then
        echo "Couldn't upload to S3 Storage... please Check .s3cfg File and/or Storage Path.."
        echo "Aborting.."
        delfiles
        touch ./.s3.ERROR
        exit
    fi    

 

    if [ -f ./.s3.ERROR || ./.db.ERROR ]; then
        rm ./*.ERROR
    fi    

    ##### Optional Sync to other bucket ########
    if [ "$MULTIBUCKET" = 1 ]; then
        s3cmd sync s3://$S3_PATH/ s3://$S3_REP_PATH/
        if [ ! "$?" = 0 ]; then
            echo "ERROR: Bucket '$S3_PATH' couldn't be synchronized with Bucket '$S3_REP_PATH'. Manual Check Required.."
        fi
    fi

    # Log
    echo "      ...database $db has been backed up"
done

echo ""
echo "...done!";
echo ""
