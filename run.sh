#!/bin/sh
set -e

if [ -z "$1" ]; then
	echo "The server argument must be set."
	exit 1
fi

if [ $SCHEME ]; then
	SCHEME_LINE="http-request set-header X-Forwarded-Proto ${SCHEME:-https}"
fi

if [ $AUTO_SSL ]; then
	openssl req -newkey rsa:2048 \
		-x509 \
		-sha256 \
		-days 3650 \
		-nodes \
		-out /ssl.crt \
		-keyout /ssl.key \
		-subj "/CN=$(hostname)"
	cat /ssl.crt /ssl.key > /ssl.pem
	rm ssl.crt ssl.key
	SSL="/ssl.pem"
fi

if [ $SSL ]; then
	BINDPARAM="ssl crt $SSL alpn h2,http/1.1"
fi

HEADERS=$(env | awk -F '=' '{
	if(index($1, "HEADER_") > 0) {
		name=substr($1, 8);
		gsub("_", "-", name);
		st=index($0, "=");
		printf("http-response set-header %s \"%s\"\n", name, substr($0, st+1))
	}
}')

COMPRESSION="
compression algo gzip
compression type text/html text/plain application/json
"

cat <<EOF > /usr/local/etc/haproxy/haproxy.cfg

global
	maxconn ${MAX_CONNECTIONS:-2000}
	tune.ssl.default-dh-param 2048

	# generated 2020-01-02, https://ssl-config.mozilla.org/#server=haproxy&server-version=2.1.0&config=intermediate
	ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
	ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
	ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

	ssl-default-server-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
	ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
	ssl-default-server-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

defaults
	mode http
	timeout connect 5s
	timeout client 30s
	timeout server 30s
	timeout queue ${QUEUE_TIMEOUT:-3s}

frontend http
	bind *:80 $BINDPARAM
	option http-buffer-request
	timeout http-request 10s
	log ${SYSLOG_SERVER:-127.0.0.1} local0
	log-format "%HM %HU %ST %TR/%Tw/%Tr/%Ta %U"
	acl is_healthcheck path ${HEALTHCHECK_PATH:-/healthcheck}
	use_backend healthcheck if is_healthcheck
	default_backend app

backend app
	server main $1 maxconn ${2:-1}
	$COMPRESSION
	$SCHEME_LINE
	$HEADERS

backend healthcheck
	server main $1

EOF

haproxy -f /usr/local/etc/haproxy/haproxy.cfg
