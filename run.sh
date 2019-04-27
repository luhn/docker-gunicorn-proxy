#!/bin/sh
set -e

if [ -z "$1" ]; then
	echo "The server argument must be set."
	exit 1
fi

if [ $SCHEME ]; then
	SCHEME_LINE="http-request set-header X-Forwarded-Proto ${SCHEME:-https}"
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

defaults
	mode http
	timeout connect 5s
	timeout client 30s
	timeout server 30s
	timeout queue ${QUEUE_TIMEOUT:-3s}

frontend http
	bind *:80
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
