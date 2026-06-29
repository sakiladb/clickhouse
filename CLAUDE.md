# CLAUDE.md

Maintainer guide for **`sakiladb/clickhouse`** — a ClickHouse Docker image preloaded with the
[Sakila](https://dev.mysql.com/doc/sakila/en/) sample database (ported from the MySQL Sakila via
[jOOQ](https://www.jooq.org/sakila)), published to
[Docker Hub](https://hub.docker.com/r/sakiladb/clickhouse) and
[GitHub Container Registry](https://github.com/sakiladb/clickhouse/pkgs/container/clickhouse).

> One of the [`sakiladb`](https://github.com/sakiladb) image family (`postgres`, `mysql`, `mariadb`,
> `sqlserver`, `oracle`, `clickhouse`, `rqlite`). The release machinery in
> [How releases work](#how-releases-work) is **shared across the family** (the reference template
> lives in [`sakiladb/postgres`](https://github.com/sakiladb/postgres)); the build details in
> [How the image is built](#how-the-image-is-built) are **ClickHouse-specific**.

## Purpose

These images exist primarily as **test fixtures for the [`sq`](https://github.com/neilotoole/sq) CLI**.
`sq`'s suite runs against every variant and asserts a uniform Sakila schema, so each image must expose
the **same object set: 16 tables + 7 views**. Treat that as a hard consistency contract.

Because the schema is coupled to `sq`'s tests, **a schema change here is a cross-repo change**: `sq`'s
expectations (`testh/sakila/sakila.go`, `libsq/driver/driver_test.go`, `cli/cmd_inspect_test.go`) must
be updated in lockstep or its suite breaks against the new image.

## The dataset

The standard Sakila database, in the `sakila` database, owned by the `sakila` user: **16 tables +
7 views**, reconciled to the canonical `sakiladb/mysql` (all verified byte-identical to
postgres/mysql). ClickHouse-specific reconciliations:

- **`film_list` is deterministic.** It aggregates the cast with
  `arrayStringConcat(arraySort(groupArray(...)), ', ')` — the `arraySort` makes the order stable
  (plain `groupArray` is non-deterministic), so the output matches the rest of the family byte-for-byte.
- **`actor_info` + `nicer_but_slower_film_list` added** (→ 7 views). `actor_info` uses a **two-stage
  `GROUP BY` rewrite** (titles per `(actor, category)`, then categories per actor) because ClickHouse's
  correlated-subquery support is weak; `arraySort` at each level keeps it deterministic.
- **`film_text` is populated + full-text-searchable.** It carries a stable **`tokenbf_v1`** data-skipping
  index over `lowerUTF8(concat(title, ' ', description))`. Unlike Oracle Text / SQLite FTS5, a
  `tokenbf_v1` index adds **no tables** and changes no columns, so it is invisible to the schema sq
  inspects — `hasToken(...,'astronaut')` returns 78, parity with the family.
- **`active` is `Bool`** on `customer` and `staff` (was `UInt8`). `Bool` is a ClickHouse alias for
  `UInt8`, so this is a zero-cost idiom upgrade; the positional integer data loads unchanged.
- **`customer_list` / `staff_list` use `` `zip code` ``** (the canonical spaced identifier).

ClickHouse has no foreign keys, triggers, or stored routines — the tables are `MergeTree` engines and
relationships are documented in comments. This is inherent to the engine and `sq`-invisible.

## How the image is built

*(ClickHouse-specific.)* `Dockerfile` is a two-stage build that **bakes the data directory** into the
image (postgres-style), so the container is ready to query within seconds of `docker run`:

1. **`builder` stage** — starts `clickhouse-server`, runs the schema, the data, then the finalize step,
   flushes, stops, and copies the populated `/var/lib/clickhouse` data tree.
2. **final stage** — copies the baked data tree + the `sakila` user config; the base entrypoint starts
   the server against the pre-loaded data.

| File | Role |
|------|------|
| `1-clickhouse-sakila-schema.sql` | Schema: `MergeTree` tables (incl. `film_text` + its `tokenbf_v1` index) and views. |
| `2-clickhouse-sakila-data.sql` | Data (`INSERT … VALUES`, positional — do not reorder columns). |
| `3-clickhouse-sakila-finalize.sql` | Populate `film_text` from `film` (must run **after** the data load). |
| `users.xml` | Creates the `sakila` user (`p_ssW0rd`). |

> The base image is `clickhouse/clickhouse-server:latest-alpine` (not version-pinned), so the `:N` tag
> tracks whatever ClickHouse `latest` is at build time. `convert_data.py` regenerates the data file
> from the MySQL Sakila dump (only needed if the data itself must change).

### Readiness (HEALTHCHECK)

The final stage declares a `HEALTHCHECK` that runs `clickhouse-client --query "SELECT 1"` over the
native protocol, so the container reports `healthy` once it is serving. (The image's embedded config
does not serve the HTTP interface on localhost, so the probe uses the native client rather than HTTP
`/ping`.)

> **Family convention:** every `sakiladb` image declares a `HEALTHCHECK` using its engine's native
> probe; the readiness *contract* (`healthy` = ready to serve) is uniform.

## How releases work

*(Shared across the `sakiladb` family — see [`sakiladb/postgres`](https://github.com/sakiladb/postgres)'s
CLAUDE.md for the full description.)* Releases are **tag-driven**: a single `master` branch, and pushing
a semver tag `vN.0.x` publishes the image, multi-arch (`linux/amd64,linux/arm64`), to **both Docker Hub
and GHCR**, **cosign-signed**. The Docker tag is the major (`v25.0.0` → `25`); `latest` tracks the
newest.

## Conventions

- **Credentials:** database / user / password = `sakila` / `sakila` / `p_ssW0rd`.
- **Tags:** Docker tag is the ClickHouse major (`25`); `latest` on the newest. Git tags are
  `v{MAJOR}.{MINOR}.{PATCH}` — the major tracks ClickHouse's (date-based) major, minor/patch track
  sakiladb's own revisions (in practice only the patch moves: `v25.0.0` → `v25.0.1`).
- **No AI attribution** in commits, tags, PRs, or any other content.
