#!/bin/sh
set -e

if [ -z "$1" ]; then
	echo "The server argument must be set."
	exit 1
fi

if [ "$LOG" = "stdout" ]; then
	LOG_LINE="access_log /var/log/nginx/access.log main;"
elif [ $LOG ]; then
	LOG_LINE="access_log $LOG main;"
else
	LOG_LINE="access_log off;"
fi

if [ $SCHEME ]; then
	SCHEME_LINE="proxy_set_header X-Forwarded-Proto $SCHEME;"
fi

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

if [ $AUTO_SSL ]; then
	openssl req -newkey rsa:2048 \
		-x509 \
		-sha256 \
		-days 3650 \
		-nodes \
		-out ssl.crt \
		-keyout ssl.key \
		-subj "/CN=$(hostname)"
	SSL_KEY=/app/ssl.key
	SSL_CRT=/app/ssl.crt
fi

if [ $SSL_KEY ]; then
	BIND="listen 8000 ssl http2;
	ssl_certificate $SSL_CRT;
	ssl_certificate_key $SSL_KEY;
	ssl_session_timeout 1d;
	ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
	ssl_session_tickets off;

	ssl_dhparam /app/dhparam.pem;

	# intermediate configuration
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
	ssl_prefer_server_ciphers off;
	"
else
	BIND="listen 8000;"
fi

cat <<EOF > /etc/nginx/nginx.conf
user nginx;
worker_processes 1;

error_log  /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;


events {
	worker_connections ${MAX_CONNECTIONS:-10000};
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
			'"time": "\$time_iso8601"}';
	$LOG_LINE

	sendfile on;
	keepalive_timeout 65;

	# gzip
	gzip on;
	gzip_proxied any;
	gzip_comp_level 6;
	gzip_buffers 16 8k;

	# Rate limiting
	$ZONE
	$LIMIT

	# Forward IPs from load balancer
	set_real_ip_from 10.0.0.0/8;
	set_real_ip_from 172.16.0.0/12;
	set_real_ip_from 192.168.0.0/16;
	real_ip_header X-Forwarded-For;

	# Limits for clients sending requests.
	client_max_body_size ${MAX_BODY_SIZE:-1m};
	client_body_timeout 5s;
	client_header_timeout 5s;

	upstream app_upstream {
		server $1 max_fails=0;
	}

	server {
		$BIND
		$HEADERS

		location / {
			proxy_pass http://app_upstream;
			proxy_redirect off;
			proxy_set_header Host \$http_host;
			proxy_set_header X-Forwarded-Proto ${SCHEME:-https};
			$SCHEME_LINE
		}
	}
}
EOF

exec nginx -g 'daemon off;'
