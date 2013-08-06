#!/bin/sh

. ${BUILDPACK_TEST_RUNNER_HOME}/lib/test_utils.sh

. ${BUILDPACK_HOME}/support/set-env.sh

assertCapturedOnStdErr()
{
	assertFileContains "$@" "${STD_ERR}"
}

testCompile()
{
	compile

	assertCapturedSuccess

	assertCaptured "-----> Installing Nginx"
	assertCaptured "Nginx v${NGINX_VERSION}"
	assertTrue "nginx should be executable" "[ -x ${BUILD_DIR}/vendor/nginx/sbin/nginx ]"

	assertCaptured "-----> Installing libmcrypt"
	assertCaptured "libmcrypt v${LIBMCRYPT_VERSION}"
	assertTrue "libmcrypt should exist" "[ -e ${BUILD_DIR}/local/lib/libmcrypt.so ]"

	assertCaptured "-----> Installing libmemcached"
	assertCaptured "libmemcached v${LIBMEMCACHED_VERSION}"
	assertTrue "libmemcached should exist" "[ -e ${BUILD_DIR}/local/lib/libmemcached.so ]"

	assertCaptured "-----> Installing PHP"
	assertCaptured "PHP v${PHP_VERSION}"
	assertTrue "php-fpm should be executable" "[ -x ${BUILD_DIR}/vendor/php/sbin/php-fpm ]"

	assertTrue "apc.so extension should exist" "[ -e ${BUILD_DIR}/vendor/php/lib/php/extensions/no-debug-non-zts-20100525/apc.so ]"
	assertTrue "memcache.so extension should exist" "[ -e ${BUILD_DIR}/vendor/php/lib/php/extensions/no-debug-non-zts-20100525/memcache.so ]"
	assertTrue "memcached.so extension should exist" "[ -e ${BUILD_DIR}/vendor/php/lib/php/extensions/no-debug-non-zts-20100525/memcached.so ]"
	assertTrue "redis.so extension should exist" "[ -e ${BUILD_DIR}/vendor/php/lib/php/extensions/no-debug-non-zts-20100525/redis.so ]"
	assertTrue "soap.so extension should exist" "[ -e ${BUILD_DIR}/vendor/php/lib/php/extensions/no-debug-non-zts-20100525/soap.so ]"


	assertCaptured "-----> Copying config files"
	assertTrue "php-fpm.conf exists and readable" "[ -r ${BUILD_DIR}/vendor/php/etc/php-fpm.conf ]"
	assertTrue "php.ini exists and readable" "[ -r ${BUILD_DIR}/vendor/php/php.ini ]"
	assertTrue "php/etc.d/ directory exists" "[ -d ${BUILD_DIR}/vendor/php/etc.d/ ]"
	assertTrue "nginx.conf.erb exists and readable" "[ -r ${BUILD_DIR}/vendor/nginx/conf/nginx.conf.erb ]"

	assertCaptured "-----> Installing boot script"
	assertTrue "boot.sh exists and executable" "[ -x ${BUILD_DIR}/boot.sh ]"

	assertCaptured "-----> Done with compile"
}

testCompiledConfig()
{
	compile

	# Test erb generation
	[ -z "`which erb`" ] && startSkipping
	PORT=3000 erb "${BUILD_DIR}/vendor/nginx/conf/nginx.conf.erb" > "${BUILD_DIR}/vendor/nginx/conf/nginx.conf"
	assertTrue "port substituted" "[ `grep -c '<%= ENV['PORT'] %>' ${BUILD_DIR}/vendor/nginx/conf/nginx.conf` -eq 0 ]"

	[ "`uname -m`" != "x86_64" ] && startSkipping
	# disable error log in config file
	#sed -i  '/error_log*/ s/^/#/' ${BUILD_DIR}/vendor/nginx/conf/nginx.conf
	# Test nginx config file
	capture ${BUILD_DIR}/vendor/nginx/sbin/nginx -t -c ${BUILD_DIR}/vendor/nginx/conf/nginx.conf
	assertCapturedOnStdErr "syntax is ok"
	#cat ${STD_ERR}
}

testCachedCompile()
{
	compile
	compile

	assertCapturedSuccess

	assertCaptured "cached Nginx v${NGINX_VERSION}"
	assertTrue "nginx should be executable" "[ -x ${BUILD_DIR}/vendor/nginx/sbin/nginx ]"

	assertCaptured "cached libmcrypt v${LIBMCRYPT_VERSION}"
	assertTrue "libmcrypt should exist" "[ -e ${BUILD_DIR}/local/lib/libmcrypt.so ]"

	assertCaptured "cached libmemcached v${LIBMEMCACHED_VERSION}"
	assertTrue "libmemcached should exist" "[ -e ${BUILD_DIR}/local/lib/libmemcached.so ]"

	assertCaptured "cached PHP v${PHP_VERSION}"
	assertTrue "php-fpm should be executable" "[ -x ${BUILD_DIR}/vendor/php/sbin/php-fpm ]"
}

testCompileCachePrune()
{
	mkdir -p ${CACHE_DIR}/bundles
	compile
	assertNotCaptured "Pruning Unused Cached Bundles"

	touch -amt '197001011234' ${CACHE_DIR}/bundles/delete_me.txt
	compile

	assertCaptured "Pruning Unused Cached Bundles"
	assertFalse "delete_me.txt should be deleted" "[ -e ${CACHE_DIR}/bundles/delete_me.txt ]"
}

testCompileComposer()
{

	[ "`uname -m`" != "x86_64" ] && startSkipping

	mkdir -p ${BUILD_DIR}/
	touch ${BUILD_DIR}/index.php

	cat >>${BUILD_DIR}/composer.json <<EOF
{
	"require": {
		"packforlan/packtest": "*@dev"
	},
	"config": {
		"notify-on-install": false
	}
}
EOF

	compile

	assertCapturedSuccess

	assertCaptured "-----> Installing dependencies using Composer"
	assertCaptured "Fetching composer.phar"
	assertTrue "composer.phar exists" "[ -f ${BUILD_DIR}/composer.phar ]"

	assertCaptured "Running: php composer.phar install"
	assertCaptured "packforlan/packtest"
	assertTrue "packforlan/packtest package exists" "[ -f ${BUILD_DIR}/vendor/packforlan/packtest/composer.json ]"

	assertTrue "composer cache exists in cache dir" "[ -d ${CACHE_DIR}/.composer/cache ]"
}
