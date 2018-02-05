#!/usr/bin/env bash
# See https://raw.githubusercontent.com/wp-cli/scaffold-command/master/templates/install-wp-tests.sh

if [ $# -lt 3 ]; then
	echo "usage: $0 <db-name> <db-user> <db-pass> [db-host] [wp-version] [skip-database-creation]"
	exit 1
fi

set -ex

DB_NAME=$1
DB_USER=$2
DB_PASS=$3
DB_HOST=${4-localhost}
WP_VERSION=${5-latest}
SKIP_DB_CREATE=${6-false}

TMPSITEURL="http://localhost:18770"
TMPSITETITLE="boxtaltest"
TMPSITEADMINLOGIN="admin"
TMPSITEADMINPWD="admin"
TMPSITEADMINEMAIL="test_wordpress@boxtal.com"
TMPDIR=${TMPDIR-./tmp}
TMPDIR=$(echo $TMPDIR | sed -e "s/\/$//")
wp='vendor/wp-cli/wp-cli/bin/wp'
productCsvParser='build/product-csv-parser.php'
TEST_DB_NAME="woocommerce_test"

download() {
    if [ `which curl` ]; then
        curl -s "$1" > "$2";
    elif [ `which wget` ]; then
        wget -nv -O "$2" "$1"
    fi
}

if [[ $WP_VERSION =~ ^[0-9]+\.[0-9]+$ ]]; then
	WP_TESTS_TAG="branches/$WP_VERSION"
elif [[ $WP_VERSION =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
	if [[ $WP_VERSION =~ [0-9]+\.[0-9]+\.[0] ]]; then
		# version x.x.0 means the first release of the major version, so strip off the .0 and download version x.x
		WP_TESTS_TAG="tags/${WP_VERSION%??}"
	else
		WP_TESTS_TAG="tags/$WP_VERSION"
	fi
elif [[ $WP_VERSION == 'nightly' || $WP_VERSION == 'trunk' ]]; then
	WP_TESTS_TAG="trunk"
else
	# http serves a single offer, whereas https serves multiple. we only want one
	download http://api.wordpress.org/core/version-check/1.7/ $TMPDIR/wp-latest.json
	grep '[0-9]+\.[0-9]+(\.[0-9]+)?' $TMPDIR/wp-latest.json
	LATEST_VERSION=$(grep -o '"version":"[^"]*' $TMPDIR/wp-latest.json | sed 's/"version":"//')
	if [[ -z "$LATEST_VERSION" ]]; then
		echo "Latest WordPress version could not be found"
		exit 1
	fi
	WP_TESTS_TAG="tags/$LATEST_VERSION"
fi

check_requirements() {
 echo 'TO DO check requirements like apache, php, mysql, php extensions'
}

create_directories() {
    WP_TESTS_DIR=${WP_TESTS_DIR-$TMPDIR/wordpress-tests-lib}
    WP_CORE_DIR=${WP_CORE_DIR-$TMPDIR/wordpress/}
    rm -rf $TMPDIR
    mkdir -p $WP_TESTS_DIR
    mkdir -p $WP_CORE_DIR
}

install_wp() {
    $wp core download --locale=fr_FR --force --version=$WP_VERSION --path=$WP_CORE_DIR
    $wp core version --path=$WP_CORE_DIR

    # parse DB_HOST for port or socket references
	local PARTS=(${DB_HOST//\:/ })
	local DB_HOSTNAME=${PARTS[0]};
	local DB_SOCK_OR_PORT=${PARTS[1]};
	local EXTRA=""

	if ! [ -z $DB_HOSTNAME ] ; then
        EXTRA=" --dbhost=$DB_HOSTNAME"
	fi
    $wp core config --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS $EXTRA --skip-check --path=$WP_CORE_DIR <<PHP
define( 'WP_DEBUG', true );
PHP

    $wp db reset --yes --path=$WP_CORE_DIR
    $wp core install --url=$TMPSITEURL --title=$TMPSITETITLE --admin_user=$TMPSITEADMINLOGIN --admin_email=$TMPSITEADMINEMAIL --admin_password=$TMPSITEADMINPWD --skip-email --path=$WP_CORE_DIR
}

install_test_suite() {
	# portable in-place argument for both GNU sed and Mac OSX sed
	if [[ $(uname -s) == 'Darwin' ]]; then
		local ioption='-i .bak'
	else
		local ioption='-i'
	fi

    svn co --quiet https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/includes/ $WP_TESTS_DIR/includes
    svn co --quiet https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/data/ $WP_TESTS_DIR/data

	if [ ! -f wp-tests-config.php ]; then
		download https://develop.svn.wordpress.org/${WP_TESTS_TAG}/wp-tests-config-sample.php "$WP_TESTS_DIR"/wp-tests-config.php
		# remove all forward slashes in the end
		WP_CORE_DIR=$(echo $WP_CORE_DIR | sed "s:/\+$::")
		echo $WP_CORE_DIR
		sed $ioption "s:dirname( __FILE__ ) . '/src/':'$WP_CORE_DIR/':" "$WP_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s/youremptytestdbnamehere/$DB_NAME/" "$WP_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s/yourusernamehere/$DB_USER/" "$WP_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s/yourpasswordhere/$DB_PASS/" "$WP_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s|localhost|${DB_HOST}|" "$WP_TESTS_DIR"/wp-tests-config.php
	fi

}

install_wc() {
    $wp plugin install woocommerce --activate --path=$WP_CORE_DIR
}

install_wc_dummy_data() {
    $wp plugin install wordpress-importer --activate --path=$WP_CORE_DIR
    $wp import $WP_CORE_DIR/wp-content/plugins/woocommerce/dummy-data/dummy-data.xml --authors='create' --path=$WP_CORE_DIR
    php $productCsvParser $WP_CORE_DIR/wp-content/plugins/woocommerce/dummy-data/dummy-data.csv
    echo 'product import success'
}

copy_plugin_to_plugin_dir() {
    cp -R src/ $WP_CORE_DIR/wp-content/plugins/boxtal-woocommerce
}

activate_plugins() {
    echo 'TO DO activate plugins & setup (OPTIONAL)'
}

check_requirements
create_directories
install_wp
install_test_suite
install_wc
install_wc_dummy_data
copy_plugin_to_plugin_dir
activate_plugins