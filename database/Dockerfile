FROM postgres:latest

RUN apt-get update && apt-get install -y cron p7zip-full && rm -rf /var/lib/apt/lists/*

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

COPY crontab /etc/cron.d/postgres-cron
RUN sed -i 's/\r$//' /etc/cron.d/postgres-cron \
    && echo "" >> /etc/cron.d/postgres-cron \
    && chmod 0644 /etc/cron.d/postgres-cron \
    && crontab /etc/cron.d/postgres-cron

CMD ["sh", "-c", "cron && docker-entrypoint.sh postgres"]
