FROM haproxy:1.8-alpine
COPY run.sh .
CMD ["/run.sh"]
