FROM postgres:11.5
COPY build.sql /docker-entrypoint-initdb.d/seed.sql
ENV POSTGRES_DB=velzy
EXPOSE 5432
