#!/bin/bash

# Check Configuration
S3_BACKUP_BUCKET=$S3_BACKUP_BUCKET

if [ -z "$S3_BACKUP_BUCKET" ]; then
  mv /root/.aws/s3-upload.sh /etc/cron.daily/
fi
