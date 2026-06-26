# sakiladb/clickhouse

A ClickHouse Docker image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) sample
database (ported from the MySQL Sakila via [jOOQ](https://www.jooq.org/sakila)). One of the
[`sakiladb`](https://github.com/sakiladb) image family.

These images exist primarily as test fixtures for [`sq`](https://github.com/neilotoole/sq), a
command-line tool for querying SQL databases and structured data — but they are free for anyone to use.

Available on [Docker Hub](https://hub.docker.com/r/sakiladb/clickhouse) and
[GitHub Container Registry](https://github.com/sakiladb/clickhouse/pkgs/container/clickhouse).

## Quick start

```shell
docker run -p 8123:8123 -p 9000:9000 -d sakiladb/clickhouse:latest
```

The image declares a Docker
[`HEALTHCHECK`](https://docs.docker.com/reference/dockerfile/#healthcheck), so you can wait for
readiness rather than guessing. Its status becomes `healthy` once ClickHouse is serving:

```shell
docker run -p 8123:8123 -p 9000:9000 -d --name sakila sakiladb/clickhouse:latest
until [ "$(docker inspect -f '{{.State.Health.Status}}' sakila)" = healthy ]; do sleep 1; done
```

## Connection

| Setting    | Value       |
|------------|-------------|
| host       | `localhost` |
| HTTP port  | `8123`      |
| native port| `9000`      |
| database   | `sakila`    |
| user       | `sakila`    |
| password   | `p_ssW0rd`  |

```shell
$ clickhouse-client -u sakila --password p_ssW0rd -d sakila -q 'SELECT actor_id, first_name, last_name FROM actor LIMIT 5'
```

## What's inside

The standard Sakila sample database — **16 tables and 7 views**, all owned by the `sakila` user, the
same object set as every other sakiladb variant.

| Tables (16) | Views (7) |
|------------|-----------|
| actor, address, category, city, country, customer, film, film_actor, film_category, film_text, inventory, language, payment, rental, staff, store | actor_info, customer_list, film_list, nicer_but_slower_film_list, sales_by_film_category, sales_by_store, staff_list |

`film_text` is a populated table with **working full-text search**, added as a stable `tokenbf_v1`
data-skipping index *under* the table (so the column set stays identical to every other variant):

```sql
SELECT title FROM sakila.film_text
WHERE hasToken(lowerUTF8(concat(title, ' ', description)), 'astronaut');
```

## Differences from other sakila variants

Every sakiladb variant exposes the **same Sakila fixture** — the same 16 tables and 7 views, with the
same data — so [`sq`](https://github.com/neilotoole/sq) can assert a uniform schema across all of them.
ClickHouse representation details:

- **Columnar engine.** Tables are `MergeTree`; ClickHouse does not enforce foreign keys and has no
  stored procedures, functions, or triggers (relationships are documented in schema comments). This is
  inherent to the engine and invisible to the uniform schema.
- **Full-text search uses `hasToken(...)`** (accelerated by the `tokenbf_v1` index), the ClickHouse
  analogue of postgres `@@` / MySQL `MATCH … AGAINST`.
- `film.special_features` is an `Array(String)`; `staff.picture` is omitted.

## Available versions

`latest` tracks the newest ClickHouse version.

| ClickHouse | sakiladb Release | Architecture     | Docker Hub                            | GitHub Container Registry                     |
|-----------:|------------------|------------------|---------------------------------------|-----------------------------------------------|
|         25 | `v25.0.1`        | `amd64`, `arm64` | `sakiladb/clickhouse:25`, `:latest`   | `ghcr.io/sakiladb/clickhouse:25`, `:latest`   |

Every version is published to both [Docker Hub](https://hub.docker.com/r/sakiladb/clickhouse) and
[GitHub Container Registry](https://github.com/sakiladb/clickhouse/pkgs/container/clickhouse), is
multi-arch (`linux/amd64`, `linux/arm64`), and is signed with [cosign](https://github.com/sigstore/cosign).

## Releasing a new version

Maintainers: releases are tag-driven. Pushing a semver tag `vN.0.x` builds and publishes the image —
the version is derived from the tag. See [CLAUDE.md](./CLAUDE.md) for the full procedure.

## Changelog

### 2026-06-26

- **Reconciled to the consistent sakiladb fixture: 16 tables + 7 views.** Added `film_text` (populated,
  with a `tokenbf_v1` full-text index — `hasToken('astronaut')` = 78) and the `actor_info` (two-stage
  `GROUP BY` rewrite) and `nicer_but_slower_film_list` views; made `film_list`'s cast order deterministic
  (`arraySort`); `customer.active` / `staff.active` are now `Bool`. Output is byte-identical to the other
  variants.
- Added a Docker `HEALTHCHECK` (`clickhouse-client … SELECT 1`).

## License

[BSD 2-Clause](./LICENSE).
