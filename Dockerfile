FROM haproxy:1.8-alpine

RUN apk add rsyslog && \
	touch /var/log/haproxy.log && \
	ln -sf /dev/stdout /var/log/haproxy.log

COPY rsyslog.conf /etc/
COPY run.sh .
ENTRYPOINT ["/run.sh"]
