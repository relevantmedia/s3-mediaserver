# Parse arguments.
MYSQL_ADMIN=root
CLOUD_DATA_URL=s3://s3.amazonaws.com/$S3_MYSQL_BUCKET/media

# Check if this is a good installation.
CLOUSE_ROOT=/tmp/clouse-1.0.2.1-linux-x64

# mysql is required.
PATH=$PATH:/usr/bin/mysql
MY_CNF=/etc/my.cnf

# Collect MySQL information.
set -e
MYSQL_INFO_SCRIPT="SELECT '@@@STATUS=', PLUGIN_STATUS FROM INFORMATION_SCHEMA.PLUGINS WHERE PLUGIN_NAME='ClouSE';SELECT '@@@VERSION=', @@VERSION;SELECT '@@@PLUGIN_DIR=', VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_VARIABLES WHERE VARIABLE_NAME='plugin_dir';"
MYSQL_INFO=`echo "$MYSQL_INFO_SCRIPT" | mysql -h localhost -u "$MYSQL_ADMIN" --disable-column-names -p"$MYSQL_ROOT_PASSWORD"`

# Parse MySQL information.
CLOUSE_STATUS=`echo "$MYSQL_INFO" | grep ^@@@STATUS= | sed -e 's/^@@@STATUS=\s*//'`
MYSQL_VERSION=`echo "$MYSQL_INFO" | grep ^@@@VERSION= | sed -e 's/^@@@VERSION=\s*//'`
MYSQL_PLUGIN_DIR=`echo "$MYSQL_INFO" | grep ^@@@PLUGIN_DIR= | sed -e 's/^@@@PLUGIN_DIR=\s*//'`

if [[ "$CLOUSE_STATUS" == ACTIVE ]]; then
    echo "ClouSE is already installed and configured, please use update-clouse."
    exit 0
fi

echo "... MySQL server version: $MYSQL_VERSION"
echo "... MySQL server plugin dir: $MYSQL_PLUGIN_DIR"

if [[ ! -d "$MYSQL_PLUGIN_DIR" ]]; then
    echo "ERROR: $MYSQL_PLUGIN_DIR is not found!!!" >&2
    exit 1
fi

MYSQL_VERSION=${MYSQL_VERSION/-log/}
MYSQL_VERSION=${MYSQL_VERSION/-cll-lve/-cll}

# Check if we support this MySQL version.
if [[ ! -f "$CLOUSE_ROOT/ha_clouse-$MYSQL_VERSION.so" ]]; then
    echo "ERROR: $CLOUSE_ROOT/ha_clouse-$MYSQL_VERSION.so is not found" >&2
    echo "    MySQL server $MYSQL_VERSION is not supported" >&2
    echo "    Send email to support@oblaksoft.com" >&2
    exit 1
fi

# Copy the so's to the plugin dir.
rm -f "$MYSQL_PLUGIN_DIR"/clouse.so
rm -f "$MYSQL_PLUGIN_DIR"/ha_clouse*.so

cp "$CLOUSE_ROOT/clouse.so" "$MYSQL_PLUGIN_DIR/"
cp "$CLOUSE_ROOT/ha_clouse-$MYSQL_VERSION.so" "$MYSQL_PLUGIN_DIR/"
ln -s "$MYSQL_PLUGIN_DIR/ha_clouse-$MYSQL_VERSION.so" "$MYSQL_PLUGIN_DIR/ha_clouse.so"

echo "ClouSE is deployed."
echo
echo "Configuring Cloud Storage Connection ..."

while true; do
    # Parse and validate URL scheme.
    CLOUD_URL_SCHEME=${CLOUD_DATA_URL%%://*}
    CLOUD_URL_HPP=${CLOUD_DATA_URL#*://}

    if [[ "$CLOUD_URL_SCHEME" == "$CLOUD_DATA_URL" ]]; then
        echo "ERROR: Bucket URL must have <scheme>://<host>/<bucket>/<prefix> format" >&2
        echo "    supported schemes are: s3, gs, walrus" >&2
        echo "    e.g: s3://s3.amazonaws.com/mybucket/myfolder" >&2
        continue
    fi

    case "$CLOUD_URL_SCHEME" in
        s3 | gs | walrus );;
        * ) echo "ERROR: $CLOUD_URL_SCHEME is not supported, must be one of s3, gs, walrus" >&2; continue;;
    esac

    # Parse host and port.
    CLOUD_URL_HP=${CLOUD_URL_HPP%%/*}
    CLOUD_URL_PATH=${CLOUD_URL_HPP#*/}

    CLOUD_URL_HOST=${CLOUD_URL_HP%%:*}
    CLOUD_URL_PORT=${CLOUD_URL_HP#*:}

    if [[ "$CLOUD_URL_PORT" == "$CLOUD_URL_HP" ]]; then
        CLOUD_URL_PORT=80
    fi

    # Parse bucket.
    CLOUD_URL_BUCKET=${CLOUD_URL_PATH%%/*}

    # Validate the arguments.
    if RESULT=`"$CLOUSE_ROOT"/wscmd -i "$CLOUD_ACCESS_KEY" -s "$CLOUD_SECRET_KEY" -U -H "$CLOUD_URL_HOST" -P "$CLOUD_URL_PORT" -n "$CLOUD_URL_BUCKET" -a listAllObjects -x 1 -d /`; then
        break
    fi

    echo "ERROR: invalid configuration $RESULT" >&2
done

CLOUD_AUTH_KEY=$CLOUD_ACCESS_KEY:$CLOUD_SECRET_KEY

# Edit my.cnf file with the entered information.
cp -p "$MY_CNF" "$MY_CNF".bak

CDU_SED=`echo "$CLOUD_DATA_URL" | sed -s 's!\\([/\\\\&]\\)!\\\\\\1!g'`
CAK_SED=`echo "$CLOUD_AUTH_KEY" | sed -s 's!\\([/\\\\&]\\)!\\\\\\1!g'`

MY_CNF_TMP=`mktemp tmp.my.cnf.XXXXXX`
trap 'rm "$MY_CNF_TMP"' EXIT

if grep -q "clouse_cloud_auth_key\s*=" "$MY_CNF"; then
    # my.cnf contains clouse_cloud_auth_key option, substitute it
    sed -e "s/^.*clouse_cloud_auth_key\s*=.*$/clouse_cloud_auth_key=$CAK_SED/" < "$MY_CNF" > "$MY_CNF_TMP"
else
    # my.cnf doesn't contain clouse_cloud_auth_key option, add it
    sed -e "/^\s*\[mysqld\]\s*$/a \
            clouse_cloud_auth_key=$CAK_SED" < "$MY_CNF" > "$MY_CNF_TMP"
fi

if grep -q "clouse_cloud_data_url\s*=" "$MY_CNF"; then
    # my.cnf contains clouse_cloud_data_url option, substitute it
    sed -e "s/^.*clouse_cloud_data_url\s*=.*$/clouse_cloud_data_url=$CDU_SED/" < "$MY_CNF_TMP" > "$MY_CNF"
else
    # my.cnf doesn't contain clouse_cloud_data_url option, add it
    sed -e "/^\s*\[mysqld\]\s*$/a \
            clouse_cloud_data_url=$CDU_SED" < "$MY_CNF_TMP" > "$MY_CNF"
fi

rm "$MY_CNF_TMP"
trap 'cp -p "$MY_CNF".bak "$MY_CNF"' EXIT

echo "Cloud Storage Connection is configured."
echo

# Install ClouSE into mysql.
echo "Installing ClouSE handlerton ..."

MYSQL_INSTALL_SCRIPT="INSTALL PLUGIN ClouSE SONAME 'ha_clouse.so';INSTALL PLUGIN CLOUSE_TABLES SONAME 'ha_clouse.so';"

set +e
INSTALL_OUT=`echo "$MYSQL_INSTALL_SCRIPT" | mysql -h localhost -u "$MYSQL_ADMIN" --disable-column-names -p"$MYSQL_ROOT_PASSWORD" 2>&1`

if [[ $? -ne 0 ]]; then
    EXIT_CODE=$?

    if ! echo $INSTALL_OUT | grep -qi "Duplicate entry 'ClouSE' for key 'PRIMARY'"; then
        echo $INSTALL_OUT >&2
        exit $EXIT_CODE
    fi

    # The plugin is already installed.  We just need to restart the server to
    # take effect.
    set -e
    MYSQL_DAEMON_SCRIPT=

    if [[ -e /etc/init.d/mysql ]]; then
        MYSQL_DAEMON_SCRIPT=/etc/init.d/mysql
    elif [[ -e /etc/init.d/mysqld ]]; then
        MYSQL_DAEMON_SCRIPT=/etc/init.d/mysqld
    elif [[ -e /etc/init.d/mysql.server ]]; then
        MYSQL_DAEMON_SCRIPT=/etc/init.d/mysql.server
    fi

    if [[ $MYSQL_DAEMON_SCRIPT ]]; then
        $MYSQL_DAEMON_SCRIPT restart
    else
        echo "Please restart MySQL server for the changes to take effect."
    fi
fi

trap - EXIT
echo "ClouSE is installed."
