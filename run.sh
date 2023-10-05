#!/bin/sh
set -e

if [ -z "$1" ]; then
	echo "The server argument must be set."
	exit 1
fi

if [ "$LOG_FORMAT" ]; then
	LOG_FORMAT_NAME="main"
	LOG_FORMAT_LINE="log_format main escape=${LOG_FORMAT_ESCAPE:-default} '$LOG_FORMAT';"
else
	LOG_FORMAT_NAME="combined"
	LOG_FORMAT_LINE=""
fi

if [ "$LOG" = "stdout" ]; then
	LOG_LINE="access_log /var/log/nginx/access.log $LOG_FORMAT_NAME;"
elif [ "$LOG" ]; then
	LOG_LINE="access_log $LOG $LOG_FORMAT_NAME;"
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
  if [ $SSL_PASSWORD_FILE ]; then
    PASSWORD_FILE="ssl_password_file $SSL_PASSWORD_FILE;"
  else
    PASSWORD_FILE=""
  fi
	BIND="listen 8000 ssl http2;
	ssl_certificate $SSL_CRT;
	ssl_certificate_key $SSL_KEY;
	$PASSWORD_FILE
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

	$LOG_FORMAT_LINE
	$LOG_LINE

	sendfile on;
	keepalive_timeout 65;
	server_tokens off;

	# gzip settings
	# Taken from https://github.com/h5bp/server-configs-nginx/blob/main/h5bp/web_performance/compression.conf
	gzip on;
	gzip_comp_level 5;
	gzip_min_length 256;
	gzip_proxied any;
	gzip_vary on;
	gzip_types
		application/atom+xml
		application/geo+json
		application/javascript
		application/x-javascript
		application/json
		application/ld+json
		application/manifest+json
		application/rdf+xml
		application/rss+xml
		application/vnd.ms-fontobject
		application/wasm
		application/x-web-app-manifest+json
		application/xhtml+xml
		application/xml
		font/eot
		font/otf
		font/ttf
		image/bmp
		image/svg+xml
		text/cache-manifest
		text/calendar
		text/css
		text/javascript
		text/markdown
		text/plain
		text/xml
		text/vcard
		text/vnd.rim.location.xloc
		text/vtt
		text/x-component
		text/x-cross-domain-policy;

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

		proxy_connect_timeout 5s;
		# proxy_send_timeout 5s;

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
