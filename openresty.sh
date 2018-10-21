#!/bin/bash

test -f /usr/bin/yum     && yum install -y libatomic_ops-devel jemalloc-devel openssl-devel unzip pcre-devel pcre2-devel git-core GeoIP-devel
test -f /usr/bin/apt-get &&  apt-get update
test -f /usr/bin/apt-get &&  apt-get install -y libbrotli-dev
test -f /usr/bin/apt-get &&  apt-get install -y libatomic-ops-dev  libjemalloc-dev libssl-dev unzip  patch build-essential  libpcre3-dev xz-utils perl-base libssl-dev zlib1g-dev libgeoip-dev git-core

TENGINE=tengine-20180816
OPENRESTY=openresty-1.13.6.2
NGX_TCP_MODULE=nginx_tcp_proxy_module-20180401
NGX_VTS=nginx-module-vts-20180722
NGX_UPSTREAM_CHECK=nginx_upstream_check_module-20180814
NGX_REQSTAT=ngx_http_reqstat_module-20180826
NGX_STICKY=nginx-sticky-module-ng-20180830
NGX_BROTLI=ngx_brotli-20180830
OPENSSL=openssl-1.1.1
PREFIX_TENGINE=/app/tengine
#PREFIX_OPENRESTY=/app   #### openresty dst: /app/openresty/sbin/nginx
PREFIX=/app/openresty
#NGINX_SBIN=/app/openresty/sbin/nginx
PREFIX_LUAJIT=$PREFIX/luajit
LOG_DIR=/app/logs/nginx/

NGX_STS=nginx-module-sts-20180830
NGX_SSTS=nginx-module-stream-sts-20180830
NGX_SSF=ngx_http_substitutions_filter_module-20180830
NGX_HC=ngx_healthcheck_module-20180916

mkdir -p ${PREFIX}/{html,temp,logs,modules,dso} $LOG_DIR
chown nobody:nobody -R ${PREFIX}/temp  $LOG_DIR

rm -rf build/*
mkdir -p build
cp -t build -r bundle/*.patch bundle/$TENGINE.zip bundle/$NGX_TCP_MODULE.zip \
      bundle/$OPENRESTY.tar.gz bundle/$OPENSSL.tar.gz bundle/$NGX_VTS.zip bundle/$NGX_REQSTAT.zip bundle/$NGX_UPSTREAM_CHECK.zip  bundle/$NGX_STICKY.zip \
      bundle/$NGX_BROTLI.zip bundle/$NGX_STS.zip bundle/$NGX_SSTS.zip  bundle/$NGX_SSF.zip bundle/$NGX_HC.zip 

cd build
workdir=$(pwd)

ls *.tar.gz | xargs -t -i tar zxf {}
ls *.zip |xargs -t -i unzip -uoq {}


test -f $PREFIX_LUAJIT/bin/luajit-2.1.0-beta3 || (
echo $PREFIX_LUAJIT/bin/luajit-2.1.0-beta3 not found,install luajit now.
sleep 5
cd $workdir/${OPENRESTY}/bundle/LuaJIT-*
# sed -i "s/^export PREFIX=.*$/export PREFIX= \/app\/nginx\/luajit/g" Makefile
sed -i 's/^export PREFIX=.*$//g' Makefile
sed -i 1"i\export PREFIX=$PREFIX_LUAJIT" Makefile
make clean
make -j4
make install
echo "[ok] install luajit"
)

cd $OPENSSL
PREFIXSSL=$PREFIX/openssl
./config --prefix=$PREFIXSSL --openssldir=$PREFIXSSL -Wl,-rpath,$PREFIXSSL/lib
make -j8 && sudo make install
$PREFIXSSL/bin/openssl ciphers -V 'ALL:COMPLEMENTOFALL'

#cd $workdir/tengine-master
#test -f .tcp.patched || ( patch -p1 < ../nginx_tcp_proxy_module-master/tcp.patch && touch .tcp.patched )

cd $workdir/${OPENRESTY}/bundle/nginx-1.*
test -f .ngxf.patched || ( patch -p0 < ../../../ngx_friendly.patch  && touch .ngxf.patched )

#test -f .ngxupc.patched || ( patch -p1 < ../../../nginx_upstream_check_module-master/check_1.12.1+.patch  && touch .ngxupc.patched )

test -f .ngxhc.patched || ( git apply ../../../ngx_healthcheck_module-master/nginx_healthcheck_for_nginx_1.14+.patch && touch .ngxhc.patched )

git apply ../../../ngx_openssl.patch

echo $workdir/${OPENRESTY}/bundle/nginx-1.*

cd $workdir/${OPENRESTY}

#cp -r ../nginx_upstream_check_module-master bundle/
#cp -r ../nginx-module-vts-master bundle/

export LUAJIT_LIB=$PREFIX_LUAJIT/lib
export LUAJIT_INC=$PREFIX_LUAJIT/include/luajit-2.1
export LUA_INCLUDE_DIR=$PREFIX_LUAJIT/include/luajit-2.1

test -f /usr/include/brotli/encode.h && add_ngx_brotli=" --add-module=../ngx_brotli-master "

test -d ../${OPENSSL} &&  custom_ssl=" --with-openssl=../${OPENSSL} "

./configure --prefix=$PREFIX \
$custom_ssl \
--with-openssl-opt='enable-tls1_3 enable-weak-ssl-ciphers' \
--with-http_ssl_module --with-http_v2_module  \
--with-libatomic  \
--with-ld-opt=-Wl,-rpath,$PREFIX_LUAJIT/lib  \
--with-pcre-jit --with-pcre \
--sbin-path=$PREFIX/sbin/nginx \
--conf-path=$PREFIX/conf/nginx.conf \
--http-log-path=${LOG_DIR}/access.log \
--error-log-path=${LOG_DIR}/error.log \
--pid-path=/var/run/nginx.pid \
--http-client-body-temp-path=$PREFIX/temp/client_body_temp \
--http-proxy-temp-path=$PREFIX/temp/proxy_temp \
--http-fastcgi-temp-path=$PREFIX/temp/fastcgi_temp \
--http-uwsgi-temp-path=$PREFIX/temp/uwsgi_temp \
--http-scgi-temp-path=$PREFIX/temp/scgi_temp \
--with-http_gzip_static_module --with-http_stub_status_module \
--with-http_secure_link_module  --with-file-aio  --with-http_realip_module \
--with-http_addition_module --with-http_sub_module  --with-http_gunzip_module \
--with-http_auth_request_module --with-http_random_index_module \
--with-http_degradation_module \
--with-http_geoip_module  \
--with-threads \
--with-stream --with-stream_ssl_module --with-stream_realip_module --with-stream_geoip_module \
--add-module=../nginx-module-vts-master \
--add-module=../ngx_http_reqstat_module-master \
--add-module=../nginx-sticky-module-ng-master \
--add-module=../ngx_http_substitutions_filter_module-master \
--add-module=../nginx-module-sts-master \
--add-module=../nginx-module-stream-sts-master \
--add-module=../ngx_healthcheck_module-master \
$add_ngx_brotli \

# --add-module=../nginx_upstream_check_module-master \
#--add-module=../${OPENRESTY}/bundle/ngx_devel_kit-0.3.0 \
#--add-module=../${OPENRESTY}/bundle/echo-nginx-module-0.61 \
#--add-module=../${OPENRESTY}/bundle/headers-more-nginx-module-0.33 \
#--add-module=../${OPENRESTY}/bundle/encrypted-session-nginx-module-0.08 \
#--add-module=../${OPENRESTY}/bundle/set-misc-nginx-module-0.32 \
#--add-module=../${OPENRESTY}/bundle/form-input-nginx-module-0.12 \
#--with-http_dyups_module   \
# --with-http_lua_module \
# --with-jemalloc
#--with-luajit-inc=$PREFIX_LUAJIT/include/luajit-2.1 \
#--with-luajit-lib=$PREFIX_LUAJIT/lib \
#--with-lua-inc=$PREFIX_LUAJIT/include/luajit-2.1 \
#--with-lua-lib=$PREFIX_LUAJIT/lib \


# workaround 1.13.6 with openssl 1.1.1
#gawk -i inplace '/pthread/ { sub(/-lpthread /, ""); sub(/-lpthread /, ""); sub(/\\/, "-lpthread \\"); print } ! /pthread/ { print }' "objs/Makefile"
#git apply ../../../ngx_openssl.patch

make -j8

#exit 

echo "" > html/index.html

cp $PREFIX/sbin/nginx $PREFIX/sbin/nginx.bak.`date "+%Y%m%d%H%M%S"` && echo "[ok] backup old nginx"
make install && echo "[ok] install new  nginx"
cp $PREFIX/sbin/nginx $PREFIX/sbin/nginx.org.`date "+%Y%m%d%H%M%S"` && echo "[ok] backup new nginx"
strip $PREFIX/sbin/* && echo "[ok] strip new nginx"
echo "" > $PREFIX/nginx/html/index.html

#cd $workdir/$NGX_VTS &&  $PREFIX_TENGINE/sbin/dso_tool -a=`pwd` -d=/app/nginx/modules && echo "[ok] install vts module"

( [[ "/app/nginx" != $PREFIX ]] && test -d /app/nginx ) || ln -s $PREFIX /app/nginx
$PREFIX/sbin/nginx -v

cd $workdir/..

# copy logrotate
test -d /etc/systemd/system &&  cp nginx.service /etc/systemd/system ||  cp nginx.init /etc/init.d/nginx
\cp -f nginx.logrotate /etc/logrotate.d/nginx

# enable service
test -f /bin/systemctl && systemctl daemon-reload
which chkconfig && chkconfig nginx on
test -f /bin/systemctl && systemctl enable nginx 
test -f /bin/systemctl || cp nginx.init /etc/init.d/nginx

# start service
#which service && service nginx start
#which service && service nginx status
