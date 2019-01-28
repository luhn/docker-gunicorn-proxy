#!/bin/sh

if [ $SYSLOG_SERVER ]; then
	LOG_TARGET=syslog:server=$SYSLOG_SERVER
else
	LOG_TARGET=/var/log/nginx/access.log
fi

cat <<EOF > /etc/nginx/nginx.conf
user nginx;
worker_processes 1;

error_log  /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;


events {
	worker_connections  1024;
}


http {
	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	log_format main escape=json '{"ip": "\$remote_addr", '
			'"method": "\$request_method", '
			'"uri": "\$request_uri", '
			'"status": "\$status", '
			'"processing_time": \$upstream_response_time, '
			'"response_time": \$request_time, '
			'"request_size": \$request_length, '
			'"time": "\$time_iso8601", '
			'"user_agent": "\$http_user_agent", '
			'"referer": "\$http_referer"}';

	access_log $LOG_TARGET main;

	sendfile on;
	keepalive_timeout 65;

	# gzip
	gzip on;
	gzip_proxied any;
	gzip_comp_level 6;
	gzip_buffers 16 8k;

	include /etc/nginx/conf.d/*.conf;
}
EOF

HEADERS=$(env | awk -F '=' '{
	if(index($1, "HEADER_") > 0) {
		name=substr($1, 8);
		gsub("_", "-", name);
		st=index($0, "=");
		printf("add_header %s \"%s\";\n", name, substr($0, st+1))
	}
}')

if [ $RATE_LIMIT ]; then
	ZONE="limit_req_zone \$binary_remote_addr zone=one:${RATE_LIMIT_SIZE:-10m} rate=${RATE_LIMIT};"
	LIMIT="limit_req zone=one"
	if [ $RATE_LIMIT_BURST ]; then
		LIMIT="$LIMIT burst=$RATE_LIMIT_BURST"
	fi
	if [ $RATE_LIMIT_NODELAY ]; then
		LIMIT="$LIMIT nodelay"
	fi
	LIMIT="$LIMIT;"
fi

cat <<EOF > /etc/nginx/conf.d/default.conf

$ZONE

upstream app_upstream {
	server $SERVER max_fails=0;
}

server {
	listen 80;

	# Forward IPs from load balancer
	set_real_ip_from 10.0.0.0/8;
	set_real_ip_from 172.16.0.0/12;
	set_real_ip_from 192.168.0.0/16;
	real_ip_header X-Forwarded-For;

	$HEADERS
	$LIMIT

	location / {
		proxy_pass http://app_upstream;
		proxy_redirect off;
		proxy_set_header Host \$http_host;
		proxy_set_header X-Forwarded-Proto ${SCHEME:-https};
	}
}

EOF

exec nginx -g 'daemon off;'
