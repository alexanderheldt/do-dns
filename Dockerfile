FROM alpine:3.12

RUN apk --no-cache add bash curl jq

COPY do-dns.sh do-dns.sh

COPY do-dns-cron /etc/cron.d/do-dns-cron
RUN chmod 0644 /etc/cron.d/do-dns-cron
RUN crontab /etc/cron.d/do-dns-cron

CMD ["crond", "-f"]
