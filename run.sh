#!/bin/sh

cat <<EOF > /etc/nginx/conf.d/default.conf

upstream app_upstream {
	server $SERVER max_fails=0;
}

server {
	listen 80;

	set_real_ip_from 10.0.0.0/8;
	set_real_ip_from 172.16.0.0/12;
	set_real_ip_from 192.168.0.0/16;
	real_ip_header X-Forwarded-For;

	location / {
		proxy_pass http://app_upstream;
		proxy_redirect off;
		proxy_set_header Host \$http_host;
		proxy_set_header X-Forwarded-Proto ${SCHEME:-https};
	}
}

EOF

exec nginx -g 'daemon off;'
