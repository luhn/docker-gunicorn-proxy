FROM nginx:1.17

ADD https://ssl-config.mozilla.org/ffdhe2048.txt /app/dhparam.pem
WORKDIR /app
EXPOSE 8000

COPY run.sh /
ENTRYPOINT ["/run.sh"]
