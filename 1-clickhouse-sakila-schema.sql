-- Sakila Sample Database Schema for ClickHouse
-- Converted from MySQL Sakila database
-- Version 1.2

-- Copyright (c) 2006, 2019, Oracle and/or its affiliates.
-- All rights reserved.
-- BSD License

-- Note: ClickHouse does not enforce foreign key constraints.
-- The relationships are documented in comments for reference.

CREATE DATABASE IF NOT EXISTS sakila;

--
-- Table structure for table `actor`
--

CREATE TABLE sakila.actor (
    actor_id UInt16,
    first_name String,
    last_name String,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY actor_id;

--
-- Table structure for table `country`
-- (Created before city due to reference)
--

CREATE TABLE sakila.country (
    country_id UInt16,
    country String,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY country_id;

--
-- Table structure for table `city`
-- References: country_id -> country.country_id
--

CREATE TABLE sakila.city (
    city_id UInt16,
    city String,
    country_id UInt16,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY city_id;

--
-- Table structure for table `address`
-- References: city_id -> city.city_id
--

CREATE TABLE sakila.address (
    address_id UInt16,
    address String,
    address2 Nullable(String),
    district String,
    city_id UInt16,
    postal_code Nullable(String),
    phone String,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY address_id;

--
-- Table structure for table `category`
--

CREATE TABLE sakila.category (
    category_id UInt8,
    name String,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY category_id;

--
-- Table structure for table `language`
--

CREATE TABLE sakila.language (
    language_id UInt8,
    name String,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY language_id;

--
-- Table structure for table `film`
-- References: language_id -> language.language_id
--             original_language_id -> language.language_id
--

CREATE TABLE sakila.film (
    film_id UInt16,
    title String,
    description Nullable(String),
    release_year Nullable(UInt16),
    language_id UInt8,
    original_language_id Nullable(UInt8),
    rental_duration UInt8 DEFAULT 3,
    rental_rate Decimal(4,2) DEFAULT 4.99,
    length Nullable(UInt16),
    replacement_cost Decimal(5,2) DEFAULT 19.99,
    rating LowCardinality(String) DEFAULT 'G',
    special_features Array(String),
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY film_id;

--
-- Table structure for table `film_actor`
-- References: actor_id -> actor.actor_id
--             film_id -> film.film_id
--

CREATE TABLE sakila.film_actor (
    actor_id UInt16,
    film_id UInt16,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (actor_id, film_id);

--
-- Table structure for table `film_category`
-- References: film_id -> film.film_id
--             category_id -> category.category_id
--

CREATE TABLE sakila.film_category (
    film_id UInt16,
    category_id UInt8,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (film_id, category_id);

--
-- Table structure for table `store`
-- References: manager_staff_id -> staff.staff_id
--             address_id -> address.address_id
--

CREATE TABLE sakila.store (
    store_id UInt8,
    manager_staff_id UInt8,
    address_id UInt16,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY store_id;

--
-- Table structure for table `staff`
-- References: address_id -> address.address_id
--             store_id -> store.store_id
-- Note: picture BLOB column omitted
--

CREATE TABLE sakila.staff (
    staff_id UInt8,
    first_name String,
    last_name String,
    address_id UInt16,
    email Nullable(String),
    store_id UInt8,
    active UInt8 DEFAULT 1,
    username String,
    password Nullable(String),
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY staff_id;

--
-- Table structure for table `customer`
-- References: store_id -> store.store_id
--             address_id -> address.address_id
--

CREATE TABLE sakila.customer (
    customer_id UInt16,
    store_id UInt8,
    first_name String,
    last_name String,
    email Nullable(String),
    address_id UInt16,
    active UInt8 DEFAULT 1,
    create_date DateTime,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY customer_id;

--
-- Table structure for table `inventory`
-- References: film_id -> film.film_id
--             store_id -> store.store_id
--

CREATE TABLE sakila.inventory (
    inventory_id UInt32,
    film_id UInt16,
    store_id UInt8,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY inventory_id;

--
-- Table structure for table `rental`
-- References: inventory_id -> inventory.inventory_id
--             customer_id -> customer.customer_id
--             staff_id -> staff.staff_id
--

CREATE TABLE sakila.rental (
    rental_id Int32,
    rental_date DateTime,
    inventory_id UInt32,
    customer_id UInt16,
    return_date Nullable(DateTime),
    staff_id UInt8,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY rental_id;

--
-- Table structure for table `payment`
-- References: customer_id -> customer.customer_id
--             staff_id -> staff.staff_id
--             rental_id -> rental.rental_id
--

CREATE TABLE sakila.payment (
    payment_id UInt16,
    customer_id UInt16,
    staff_id UInt8,
    rental_id Nullable(Int32),
    amount Decimal(5,2),
    payment_date DateTime,
    last_update DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY payment_id;

--
-- View structure for view `customer_list`
--

CREATE VIEW sakila.customer_list AS
SELECT
    cu.customer_id AS ID,
    concat(cu.first_name, ' ', cu.last_name) AS name,
    a.address AS address,
    a.postal_code AS `zip code`,
    a.phone AS phone,
    city.city AS city,
    country.country AS country,
    if(cu.active, 'active', '') AS notes,
    cu.store_id AS SID
FROM sakila.customer AS cu
JOIN sakila.address AS a ON cu.address_id = a.address_id
JOIN sakila.city ON a.city_id = city.city_id
JOIN sakila.country ON city.country_id = country.country_id;

--
-- View structure for view `staff_list`
--

CREATE VIEW sakila.staff_list AS
SELECT
    s.staff_id AS ID,
    concat(s.first_name, ' ', s.last_name) AS name,
    a.address AS address,
    a.postal_code AS `zip code`,
    a.phone AS phone,
    city.city AS city,
    country.country AS country,
    s.store_id AS SID
FROM sakila.staff AS s
JOIN sakila.address AS a ON s.address_id = a.address_id
JOIN sakila.city ON a.city_id = city.city_id
JOIN sakila.country ON city.country_id = country.country_id;

--
-- View structure for view `sales_by_store`
--

CREATE VIEW sakila.sales_by_store AS
SELECT
    concat(c.city, ',', cy.country) AS store,
    concat(m.first_name, ' ', m.last_name) AS manager,
    sum(p.amount) AS total_sales
FROM sakila.payment AS p
INNER JOIN sakila.rental AS r ON p.rental_id = r.rental_id
INNER JOIN sakila.inventory AS i ON r.inventory_id = i.inventory_id
INNER JOIN sakila.store AS s ON i.store_id = s.store_id
INNER JOIN sakila.address AS a ON s.address_id = a.address_id
INNER JOIN sakila.city AS c ON a.city_id = c.city_id
INNER JOIN sakila.country AS cy ON c.country_id = cy.country_id
INNER JOIN sakila.staff AS m ON s.manager_staff_id = m.staff_id
GROUP BY s.store_id, c.city, cy.country, m.first_name, m.last_name
ORDER BY cy.country, c.city;

--
-- View structure for view `sales_by_film_category`
-- Note: Total sales may exceed 100% because some films belong to multiple categories
--

CREATE VIEW sakila.sales_by_film_category AS
SELECT
    c.name AS category,
    sum(p.amount) AS total_sales
FROM sakila.payment AS p
INNER JOIN sakila.rental AS r ON p.rental_id = r.rental_id
INNER JOIN sakila.inventory AS i ON r.inventory_id = i.inventory_id
INNER JOIN sakila.film AS f ON i.film_id = f.film_id
INNER JOIN sakila.film_category AS fc ON f.film_id = fc.film_id
INNER JOIN sakila.category AS c ON fc.category_id = c.category_id
GROUP BY c.name
ORDER BY total_sales DESC;

--
-- View structure for view `film_list`
--

CREATE VIEW sakila.film_list AS
SELECT
    film.film_id AS FID,
    film.title AS title,
    film.description AS description,
    category.name AS category,
    film.rental_rate AS price,
    film.length AS length,
    film.rating AS rating,
    arrayStringConcat(
        groupArray(concat(actor.first_name, ' ', actor.last_name)),
        ', '
    ) AS actors
FROM sakila.category
LEFT JOIN sakila.film_category ON category.category_id = film_category.category_id
LEFT JOIN sakila.film ON film_category.film_id = film.film_id
JOIN sakila.film_actor ON film.film_id = film_actor.film_id
JOIN sakila.actor ON film_actor.actor_id = actor.actor_id
GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;
