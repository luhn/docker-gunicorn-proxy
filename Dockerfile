FROM haproxy:2.1

RUN apt-get update && \
	apt-get install -y openssl && \
	rm -rf /var/lib/apt/lists/*

COPY run.sh .
ENTRYPOINT ["/run.sh"]
