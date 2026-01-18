#!/usr/bin/env bash

# Run the pre-built ClickHouse Sakila image from Docker Hub
docker run -p 8123:8123 -p 9000:9000 -d sakiladb/clickhouse:latest
