FROM postgres:15-alpine

RUN chown -R postgres:postgres /var/lib/postgresql && \
    chown -R postgres:postgres /var/run/postgresql

USER postgres

EXPOSE 5432
