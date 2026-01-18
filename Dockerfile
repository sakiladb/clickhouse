# Multi-stage build for ClickHouse with pre-loaded Sakila database
# Based on the pattern from postgres/Dockerfile

FROM clickhouse/clickhouse-server:latest-alpine AS builder

# Copy SQL initialization scripts
COPY ./1-clickhouse-sakila-schema.sql /docker-entrypoint-initdb.d/
COPY ./2-clickhouse-sakila-data.sql /docker-entrypoint-initdb.d/

# Copy users configuration (creates sakila user with p_ssW0rd password)
COPY ./users.xml /etc/clickhouse-server/users.d/sakila_users.xml

# Initialize the database by starting ClickHouse, running scripts, then stopping
# Note: ClickHouse uses embedded config which stores data in / (root) by default
RUN /entrypoint.sh clickhouse-server & \
    sleep 10 && \
    # Wait for server to be ready (try up to 60 seconds)
    for i in $(seq 1 60); do \
        if clickhouse-client --query "SELECT 1" 2>/dev/null; then break; fi; \
        sleep 1; \
    done && \
    # Run schema creation
    clickhouse-client --multiquery < /docker-entrypoint-initdb.d/1-clickhouse-sakila-schema.sql && \
    # Verify database was created
    clickhouse-client --query "SHOW DATABASES" && \
    # Run data insertion
    clickhouse-client --multiquery < /docker-entrypoint-initdb.d/2-clickhouse-sakila-data.sql && \
    # Verify data was inserted
    clickhouse-client --query "SELECT count(*) FROM sakila.actor" && \
    # Flush all data to disk
    clickhouse-client --query "SYSTEM FLUSH LOGS" && \
    sync && \
    sleep 2 && \
    # Stop the server gracefully
    pkill -f clickhouse-server || true && \
    sleep 5 && \
    # Move data from root (embedded config location) to standard location
    mkdir -p /var/lib/clickhouse && \
    cp -r /data /var/lib/clickhouse/ && \
    cp -r /metadata /var/lib/clickhouse/ && \
    cp -r /store /var/lib/clickhouse/ && \
    cp -r /flags /var/lib/clickhouse/ && \
    cp -r /format_schemas /var/lib/clickhouse/ && \
    cp -r /metadata_dropped /var/lib/clickhouse/ && \
    cp -r /preprocessed_configs /var/lib/clickhouse/ && \
    cp -r /user_files /var/lib/clickhouse/ && \
    cp /uuid /var/lib/clickhouse/ && \
    chown -R clickhouse:clickhouse /var/lib/clickhouse

# Final image
FROM clickhouse/clickhouse-server:latest-alpine

# Copy pre-initialized data directory from builder
COPY --from=builder /var/lib/clickhouse /var/lib/clickhouse

# Copy users configuration from builder
COPY --from=builder /etc/clickhouse-server/users.d/sakila_users.xml /etc/clickhouse-server/users.d/

# Expose ports: 8123 (HTTP), 9000 (native protocol)
EXPOSE 8123 9000

# The default entrypoint and CMD from the base image will start ClickHouse
