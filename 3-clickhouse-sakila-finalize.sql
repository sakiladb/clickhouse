-- Populate film_text from film. Runs after the data load
-- (2-clickhouse-sakila-data.sql) — the film rows must exist first. The table and
-- its tokenbf_v1 full-text index are defined in 1-clickhouse-sakila-schema.sql;
-- this just fills it.
INSERT INTO sakila.film_text (film_id, title, description)
    SELECT film_id, title, ifNull(description, '') FROM sakila.film;
