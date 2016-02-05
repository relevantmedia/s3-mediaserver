#!/bin/bash

if [ "$MYSQL_ROOT_HOST" ]; then
  echo "Change MySQL host for root user to ${MYSQL_ROOT_HOST}"
  MYSQL_USER_SCRIPT="UPDATE mysql.user SET host='"${MYSQL_ROOT_HOST}"' WHERE host='%' AND user='root'; FLUSH PRIVILEGES;"
  echo "$MYSQL_USER_SCRIPT" | mysql -h localhost -u root -p$MYSQL_ROOT_PASSWORD
  echo 'MySQL host changed for root user'
fi
