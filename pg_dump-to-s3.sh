#!/bin/bash

# Adding Bashframe
. ./bashframe/sysutils.sh

############################### FUNCTIONS
# Delete local file
delfiles()
{
    echo "DEBUG: REMOVING TEMPFILES"
    rm /tmp/"$FILENAME".dump
}

###########################################

echo "Set current directory"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Import config file"
source ./pg_dump-to-s3.conf

# Vars
NOW=$(date +"%d%m%Y%H%M")

echo "split databases"
IFS=',' read -ra DBS <<< "$PG_DATABASES"

echo " * Backup in progress.,.";

echo "Loop thru databases"
for db in "${DBS[@]}"; do
    FILENAME="$db"


    echo "   -> backing up $db..."

    # Dump database
    echo "DEBUG: START PG_DUMP"
    pg_dump -Fc -w -h $PG_HOST -U $PG_USER -p $PG_PORT $db > /tmp/"$FILENAME".dump
    echo "DEBUG: END PG_DUMP"

    if [ ! "$?" = 0 ]; then
        echo "DB-Connection didn't work... Aborting."
        exit
    fi

    if [ "$DUMP_ENC" = 1 ]; then
         checkInstall "gpg"
         if [ ! "$?" = 0 ]; then
            echo "gpg not installed, can't encrypt."
            echo "Use following command to install required utilities:"
            echo 'sudo apt/yum install gpg -y'
            exit 1
        fi

        echo "Trying to encrypt dump.."
        gpg -e --always-trust -r $GPG_USER /tmp/"$FILENAME".dump
        if [ ! "$?" = 0 ]; then
           echo  "No key's available.. Trying to Import."

           if [ -z "$GPG_PUBK" ]; then
		 echo "Public Key Path not set... Aborting"
		 exit 1
	    fi

           gpg --import $GPG_PUBK
           gpg -e -r $GPG_USER /tmp/"$FILENAME".dump
           rm /tmp/"$FILENAME".dump
	   mv /tmp/"$FILENAME".dump.gpg /tmp/"$FILENAME".dump
        else
	    rm /tmp/"$FILENAME".dump
            mv /tmp/"$FILENAME".dump.gpg /tmp/"$FILENAME".dump
	   echo "DEBUG:test"
	 fi

   fi

     #Copy to S3
     s3cmd put /tmp/"$FILENAME".dump s3://$S3_PATH/"dump_"$NOW/"$FILENAME".dump --storage-class STANDARD_IA
     if [ ! "$?" = 0 ]; then
        echo "Couldn't upload to S3 Storage... please Check .s3cfg File and/or Storage Path.."
        echo "Aborting.."
        delfiles
        exit
     else
	echo "File $FILENAME successfully uploaded to s3!"
	delfiles
     fi
    ##### Optional Sync to other bucket ########
    if [ "$MULTIBUCKET" = 1 ]; then
        s3cmd sync s3://$S3_PATH/ s3://$S3_REP_PATH/
        if [ ! "$?" = 0 ]; then
            echo "ERROR: Bucket '$S3_PATH' couldn't be synchronized with Bucket '$S3_REP_PATH'. Manual Check Required.."
        fi
    fi
    ###############################################

    # Log
    echo "      ...database $db has been backed up"
done

echo ""
echo "...done!";
echo ""