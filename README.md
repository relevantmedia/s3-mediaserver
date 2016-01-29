# s3-mediaserver
Dockerized MYSQL server with CLOUSE mysql plugin installed to connect to s3

Docker takes several environment variables.

Configure the CLOUSE plugin with its own IAM keys to give mysql access to write to an s3 bucket.
CLOUD_DATA_URL=s3://s3.amazonaws.com/s3bucket
CLOUD_SECRET_KEY=aws_secret_access_key
CLOUD_ACCESS_KEY=aws_access_key_id

MYSQL Config
Installs mysql server 5.6.28

MYSQL_ROOT_PASSWORD
MYSQL_DATABASE
MYSQL_USER
MYSQL_PASSWORD
