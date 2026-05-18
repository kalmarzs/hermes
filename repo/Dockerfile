FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    reprepro \
    gnupg \
    nginx \
    && rm -rf /var/lib/apt/lists/*

ENV GNUPGHOME=/gnupg

RUN mkdir -p /repo/conf

COPY conf/distributions /repo/conf/distributions
COPY conf/options /repo/conf/options
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80

CMD ["/entrypoint.sh"]
