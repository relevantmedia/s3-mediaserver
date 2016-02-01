#!/bin/bash

# Configuration
# MYSQL_USER, MYSQL_PASSWORD and MYSQL_DATABASE are set as ENV variables
DATE=$(date +%Y%m%d)
DATETIME=$(date +%Y%m%d-%H%m)

BUCKET_NAME=$S3_BACKUP_BUCKET
## Specify where the backups should be placed
S3_BUCKET_URL=s3://$BUCKET_NAME/cloudse/$DATE/
BACKUP_DIRECTORY=/tmp/backups/


## The script
cd /
mkdir -p $BACKUP_DIRECTORY
rm -rf $BACKUP_DIRECTORY/*
BACKUP_FILE=$BACKUP_DIRECTORY/${DATETIME}_${MYSQL_DATABASE}.sql
mysqldump -v -h localhost -u $MYSQL_USER --password=$MYSQL_PASSWORD -r $BACKUP_FILE $MYSQL_DATABASE
gzip $BACKUP_FILE
aws s3 cp ${BACKUP_FILE}.gz $S3_BUCKET_URL
