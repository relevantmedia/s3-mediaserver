#!/bin/bash

# Check Configuration
DATE=$(date +%Y%m%d)
S3_BACKUP_BUCKET=$S3_BACKUP_BUCKET
BACKUP_DIRECTORY=/tmp/backups/
SQL_FILE=$BACKUP_DIRECTORY/*.sql

if [ -z "$S3_BACKUP_BUCKET" ]; then
  ## create bucket if it does not exits
  aws s3 mb s3://$S3_BACKUP_BUCKET
  mkdir -p $BACKUP_DIRECTORY
  aws s3 cp s3://$S3_BACKUP_BUCKET/clouse/$DATE/ $BACKUP_DIRECTORY --include "*.sql.gz"
  gzip -d $BACKUP_DIRECTORY/*.gz
  mysql -h localhost -u root -p"$MYSQL_ROOT_PASSWORD" $MYSQL_DATABASE < $SQL_FILE
  ## move bash script to run daily
  mv /root/.aws/s3-upload.sh /etc/cron.daily/
fi
