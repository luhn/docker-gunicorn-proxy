FROM nginx:1.15-alpine
COPY run.sh .
CMD ["/run.sh"]
