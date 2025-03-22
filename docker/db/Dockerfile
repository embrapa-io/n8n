FROM postgres:17

COPY /docker/db/init-data.sh /docker-entrypoint-initdb.d/
RUN chmod 0755 /docker-entrypoint-initdb.d/init-data.sh
