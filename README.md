# sakiladb/clickhouse

ClickHouse docker image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) example
database (by way of [jOOQ](https://www.jooq.org/sakila)).
See on [Docker Hub](https://hub.docker.com/r/sakiladb/clickhouse).

By default these are created:
- database: `sakila`
- username / password: `sakila` / `p_ssW0rd`

## Quick Start

```shell
docker run -p 8123:8123 -p 9000:9000 -d sakiladb/clickhouse:latest
```

## Build Locally

```shell
docker build -t sakiladb/clickhouse:latest .
```

## Ports

- `8123`: HTTP interface
- `9000`: Native TCP protocol

## Verify Installation

Using the native client:

```shell
$ docker exec -it $(docker ps -q -f ancestor=sakiladb/clickhouse:latest) \
    clickhouse-client -u sakila --password p_ssW0rd -d sakila \
    -q 'SELECT * FROM actor LIMIT 5'
```

Output:

```
┌─actor_id─┬─first_name─┬─last_name────┬─────────last_update─┐
│        1 │ PENELOPE   │ GUINESS      │ 2006-02-15 04:34:33 │
│        2 │ NICK       │ WAHLBERG     │ 2006-02-15 04:34:33 │
│        3 │ ED         │ CHASE        │ 2006-02-15 04:34:33 │
│        4 │ JENNIFER   │ DAVIS        │ 2006-02-15 04:34:33 │
│        5 │ JOHNNY     │ LOLLOBRIGIDA │ 2006-02-15 04:34:33 │
└──────────┴────────────┴──────────────┴─────────────────────┘
```

Using curl (HTTP interface):

```shell
$ curl 'http://localhost:8123/?user=sakila&password=p_ssW0rd' \
    -d 'SELECT count(*) FROM sakila.actor'
200
```

## Tables

The following tables are available:

| Table         | Row Count |
|---------------|-----------|
| actor         | 200       |
| address       | 603       |
| category      | 16        |
| city          | 600       |
| country       | 109       |
| customer      | 599       |
| film          | 1000      |
| film_actor    | 5462      |
| film_category | 1000      |
| inventory     | 4581      |
| language      | 6         |
| payment       | 16049     |
| rental        | 16044     |
| staff         | 2         |
| store         | 2         |

## Views

The following views are available:

- `customer_list` - Customer information with address details
- `staff_list` - Staff information with address details
- `sales_by_store` - Total sales grouped by store
- `sales_by_film_category` - Total sales grouped by film category
- `film_list` - Film information with actors

## Notes

- ClickHouse does not support stored procedures, functions, or triggers
- Foreign key constraints are not enforced (documented in schema comments)
- The `film_text` table is omitted (MySQL FULLTEXT search table)
- The `actor_info` view is omitted (uses correlated subqueries not supported)
- The `special_features` column in `film` is stored as `Array(String)`
- The `picture` BLOB column is omitted from the `staff` table
