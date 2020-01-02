FROM haproxy:2.1

RUN apt-get update && \
	apt-get install -y openssl && \
	rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --home /haproxy haproxy
USER haproxy
WORKDIR /haproxy
EXPOSE 8000

COPY run.sh /
ENTRYPOINT ["/run.sh"]
