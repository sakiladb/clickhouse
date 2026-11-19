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
image (postgres-style), so the container is ready to query within seconds of `docker run`. The
base-image version is parameterized by an `ARG CH_VERSION` (a ClickHouse release, `YY.M`; default =
newest), which the release workflow sets per build:

1. **`builder` stage** — `FROM clickhouse/clickhouse-server:${CH_VERSION}-alpine`, starts
   `clickhouse-server`, **asserts `SELECT version()` is `${CH_VERSION}.x`** (the build fails
   otherwise, so a tag can never disagree with the server inside), runs the schema, the data, then
   the finalize step, flushes, stops, and copies the populated `/var/lib/clickhouse` data tree.
2. **final stage** — `FROM` the same base again, copies the baked data tree + the `sakila` user
   config; the base entrypoint starts the server against the pre-loaded data.

| File | Role |
|------|------|
| `1-clickhouse-sakila-schema.sql` | Schema: `MergeTree` tables (incl. `film_text` + its `tokenbf_v1` index) and views. |
| `2-clickhouse-sakila-data.sql` | Data (`INSERT … VALUES`, positional — do not reorder columns). |
| `3-clickhouse-sakila-finalize.sql` | Populate `film_text` from `film` (must run **after** the data load). |
| `users.xml` | Creates the `sakila` user (`p_ssW0rd`). |

> `convert_data.py` regenerates the data file from the MySQL Sakila dump (only needed if the data
> itself must change).

### Readiness (HEALTHCHECK)

The final stage declares a `HEALTHCHECK` that runs `clickhouse-client --query "SELECT 1"` over the
native protocol, so the container reports `healthy` once it is serving. (The image's embedded config
does not serve the HTTP interface on localhost, so the probe uses the native client rather than HTTP
`/ping`.)

> **Family convention:** every `sakiladb` image declares a `HEALTHCHECK` using its engine's native
> probe; the readiness *contract* (`healthy` = ready to serve) is uniform.

## How releases work

*(Shared across the `sakiladb` family — see [`sakiladb/postgres`](https://github.com/sakiladb/postgres)'s
CLAUDE.md for the full description, incl. attestations.)* Releases are **tag-driven**: a single
`master` branch, and pushing a semver tag publishes the image, multi-arch
(`linux/amd64,linux/arm64`), to **both Docker Hub and GHCR**, **cosign-signed**, with provenance +
SBOM attestations.

**ClickHouse-specific: the version is `YY.M`, not a major.** ClickHouse versions are `YY.M.patch.build`
with roughly monthly releases, so a "major" is just a year spanning a dozen differing releases. The
unit that matters is the release, `YY.M`, so the git tag is `v{YY}.{M}.{x}` and the Docker tag is
`{{major}}.{{minor}}`: **`v25.8.0` publishes `:25.8`, which runs ClickHouse 25.8.x**. The patch
(`x`) is sakiladb's own revision of that release.

- The **"Determine ClickHouse version" step** computes the release: from the `ch_version` input on a
  manual run; from the tag (`v25.8.1` → `25.8`) on a tag push; otherwise `LATEST_VERSION`. It is
  validated (`YY.M`, digits only) and passed as `--build-arg CH_VERSION=…`.
- Only `v*.*.*` tag pushes publish. Branch pushes, PRs, and manual `workflow_dispatch` runs are
  build-only smoke tests.
- **`latest`** is never auto-assigned (`flavor: latest=false`); it is emitted only when the tag's
  release equals the workflow's **`LATEST_VERSION`** env var, so tag-push order is irrelevant and
  republishing an older release can never steal `latest`.

**Which releases to publish:** the newest release, plus the LTS releases (ClickHouse designates the
`.3` and `.8` releases of each year as LTS), e.g. `26.10`, `26.8`, `26.3`, `25.8`, `25.3`. Upstream
drops support for non-LTS releases quickly, so intermediate monthlies are not kept current.

### Recipe: release a new newest ClickHouse (e.g. 26.11)

```bash
git switch master && git pull
# 1. In .github/workflows/docker-publish.yml, bump:  LATEST_VERSION: "26.11"
# 2. Bump the Dockerfile's `ARG CH_VERSION=26.11` default (local builds).
git commit -am "clickhouse 26.11 is now the newest"
git push origin master                       # build-only smoke test
git tag v26.11.0 && git push origin v26.11.0 # publishes `26.11` + `latest`
```

### Recipe: publish or rebuild any release (e.g. 25.8)

```bash
git switch master && git pull
git tag -l 'v25.8.*'                         # pick the next unused patch
git tag v25.8.1 && git push origin v25.8.1   # publishes `25.8`; `latest` untouched
```

To preview without publishing: Actions ▸ Docker ▸ Run workflow ▸ `ch_version = 25.8`, or locally
`docker build --build-arg CH_VERSION=25.8 .`.

After any release: pull the image, confirm `SELECT version()` and the schema (16 tables + 7 views),
confirm `latest` still points at the newest, and update the README "Available versions" table (and
Changelog, if user-visible).

> **Legacy `:25` tag.** Releases `v25.0.0`–`v25.0.4` predate this scheme: they built from
> `latest-alpine` and published `:25`, where `25` was a release counter, not a ClickHouse version
> (the last `:25` actually runs ClickHouse 26.5). `:25` is frozen (no workflow path republishes it)
> and must stay in the registries until `sq` (`.github/sakila-db.json`, `docs/SAKILA.md`) has moved
> to `YY.M` tags; then delete it. A new `v25.0.x` tag would try to build the non-existent ClickHouse
> `25.0` and fail, by design.

## Conventions

- **Credentials:** database / user / password = `sakila` / `sakila` / `p_ssW0rd`.
- **Tags:** Docker tag is the ClickHouse release, `YY.M` (`25.8`, `26.10`); `latest` on the newest.
  Git tags are `v{YY}.{M}.{PATCH}` — major.minor is the ClickHouse release, the patch is sakiladb's
  own revision (`v25.8.0` → `v25.8.1`).
- **No AI attribution** in commits, tags, PRs, or any other content.
