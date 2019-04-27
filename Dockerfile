FROM haproxy:1.8-alpine
COPY run.sh .
ENTRYPOINT ["/run.sh"]
