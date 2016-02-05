# s3-mediaserver
Dockerized MYSQL server with CLOUSE mysql plugin installed to connect to s3

### Configure your mysql installation
This server installs mysql server 5.6.28
```
docker run --name my-container-name -e MYSQL_ROOT_PASSWORD=my-mysql-root-password -e MYSQL_USER=mysql-user -e MYSQL_PASSWORD=mysql-user-password -e MYSQL_DATABASE=mysql-database -d
```
`MYSQL_ROOT_PASSWORD` must be set for installation to complete. You have the option of adding another user and database during the run process.

By default when mysql is installed the the root user has access from anywhere `'root'@'%'`. Use `-e MYSQL_ROOT_HOST=localhost` or a specific ip address if you want to limit access to mysql running on your container.

### Configure the CLOUSE mysql plugin to connect to S3
Configure the CLOUSE plugin with its own IAM keys to give mysql access to write to an s3 bucket. The CLOUSE plugin was written by oblaksoft and documentaion can be found here.

```
docker run --name my-container-name -e CLOUD_ACCESS_KEY=aws_access_key_id -e CLOUD_SECRET_KEY=aws_secret_access_key -e S3_MYSQL_BUCKET=my-mysql-bucket -d
```
The mysql bucket is used to dump media and link to the url stored in the mysql table. If you are running wordpress and a cdn, you should use the same bucket as the rest of your wordpress installation.

The `CLOUD_ACCESS_KEY and CLOUD_SECRET_KEY` are your IAM credentials that you set up on AWS.

### Using this media server with Wordpress

## S3 Backup of mysql server
You can optionally configure the aws cli to backup your chosen database to another bucket on S3. You must specify the IAM credentials for the cli to access S3 as well as the new bucket you have created for the sql data.

```
docker run --name my-container-name -e AWS_ACCESS_KEY_ID=my-s3-backup-access-key -e AWS_SECRET_ACCESS_KEY=my-s3-backup-secret-key -e S3_BACKUP_BUCKET=s3-bucket-name -d
```
