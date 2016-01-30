#!/bin/bash

# Configuration
# MYSQL_USER, MYSQL_PASSWORD and MYSQL_DATABASE are set as ENV variables
DATE=$(date +%Y%m%d)
DATETIME=$(date +%Y%m%d-%H%m)

BUCKET_NAME=$S3_BUCKET_NAME
## Specify where the backups should be placed
S3_BUCKET_URL=s3://$BUCKET_NAME/cloudse/$DATE/
BACKUP_DIRECTORY=/tmp/backups/
## Specify directoryes to backup (it's clever to use relaive paths)
DIRECTORIES="etc/cron.daily etc/mysql"


## The script
cd /
mkdir -p $BACKUP_DIRECTORY
rm -rf $BACKUP_DIRECTORY/*
# Backup from docker container
# sudo docker exec $CONTAINER_NAME sh -c "mysqldump -h localhost -u \"$MYSQL_USER \"-p\"$MYSQL_PASSWORD $MYSQL_DB \"> /tmp/\"$FILENAME"
# sudo docker cp $CONTAINER_NAME:/tmp/$FILENAME $BACKUP_DIRECTORY
# sudo docker exec $CONTAINER_NAME sh -c "rm /tmp/\"$MYSQL_DB\"-*.sql"
BACKUP_FILE=$BACKUP_DIRECTORY/${DATETIME}_${MYSQL_DATABASE}.sql
mysqldump -v -h localhost -u $MYSQL_USER --password=$MYSQL_PASSWORD -r $BACKUP_FILE $MYSQL_DATABASE
gzip $BACKUP_FILE
aws s3 cp ${BACKUP_FILE}.gz $S3_BUCKET_URL

for DIR in $DIRECTORIES
do
BACKUP_FILE=$BACKUP_DIRECTORY/${DATETIME}_$(echo $DIR | sed 's/\//-/g').tgz
/bin/tar zcvf ${BACKUP_FILE} $DIR 2>&1
$S3_CMD put ${BACKUP_FILE} $S3_BUCKET_URL 2>&1
done
