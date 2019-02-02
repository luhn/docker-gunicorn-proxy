#!/bin/sh

if [ $SCHEME ]; then
	SCHEME_LINE="http-request set-header X-Forwarded-Proto ${SCHEME:-https}"
fi

cat <<EOF > /usr/local/etc/haproxy/haproxy.cfg

global
	maxconn 256

defaults
	mode http
	timeout connect 5s
	timeout client 30s
	timeout server 30s
	timeout queue ${QUEUE_TIMEOUT:-3s}

frontend http
	bind *:80
	acl is_healthcheck path ${HEALTHCHECK_PATH:-/healthcheck}
	use_backend healthcheck if is_healthcheck
	default_backend app

backend app
	server main $SERVER maxconn $CONCURRENCY
	$SCHEME_LINE

backend healthcheck
	server main $SERVER

EOF

haproxy -f /usr/local/etc/haproxy/haproxy.cfg
