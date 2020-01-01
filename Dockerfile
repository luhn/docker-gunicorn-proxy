FROM haproxy:2.1
COPY run.sh .
ENTRYPOINT ["/run.sh"]
