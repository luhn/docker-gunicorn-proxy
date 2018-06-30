FROM nginx:1.15-alpine
COPY run.sh .
RUN chmod +x run.sh
CMD ["/run.sh"]
