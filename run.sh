#!/bin/sh

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
	default_backend app

backend app
	server main $SERVER maxconn $CONCURRENCY

EOF

haproxy -f /usr/local/etc/haproxy/haproxy.cfg
