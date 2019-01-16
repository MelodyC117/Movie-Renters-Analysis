/*1.What are top 10 paying customers' favorite categories that accounted for more than 10% of their gross payment?*/


WITH table_1 AS
(
         SELECT   Sum(pmt.amount)            AS top10_payment,
                  cust.first_name
                   || ' '
                   || cust.last_name         AS full_name
         FROM     payment  AS pmt
         JOIN     customer AS cust
         ON       pmt.customer_id = cust.customer_id
         GROUP BY 2
         ORDER BY 1 DESC
         LIMIT 10)

SELECT   full_name,
         cat.NAME                        AS cat_name,
         Sum(pmt.amount)                 AS total_cat,
         top10_payment,
         Sum(pmt.amount) / top10_payment AS percent_total
FROM     category      AS cat
JOIN     film_category AS film_cat
ON       film_cat.category_id = cat.category_id
JOIN     film          AS film
ON       film.film_id = film_cat.film_id
JOIN     inventory     AS inv
ON       inv.film_id = film.film_id
JOIN     rental        AS rent
ON       rent.inventory_id = inv.inventory_id
JOIN     payment       AS pmt
ON       pmt.rental_id = rent.rental_id
JOIN     customer      AS cust
ON       pmt.customer_id = cust.customer_id
JOIN     table_1
ON       table_1.full_name = cust.first_name
                              || ' '
                              || cust.last_name
GROUP BY 2, 1, 4
HAVING Sum(pmt.amount) / top10_payment >= 0.1
ORDER BY 4 DESC, 3 DESC, 2, 1

/*2. what ratings of films do Customers from top 10 renting countries prefer?*/


WITH table_1 AS
(
         SELECT   country.country AS country,
                  Count(*)        AS country_rank
         FROM     country         AS country
         JOIN     city            AS city
         ON       country.country_id = city.country_id
         JOIN     address  AS address
         ON       city.city_id = address.city_id
         JOIN     customer AS cust
         ON       cust.address_id = address.address_id
         JOIN     rental   AS rent
         ON       rent.customer_id = cust.customer_id
         GROUP BY 1
         ORDER BY 2 DESC
         LIMIT 10
)

SELECT   table_1.country AS country,
         film.rating     AS rating,
         Count(*)        AS total_film,
         country_rank
FROM     film      AS film
JOIN     inventory AS inv
ON       film.film_id = inv.film_id
JOIN     rental    AS rent
ON       rent.inventory_id = inv.inventory_id
JOIN     customer  AS cust
ON       cust.customer_id = rent.rental_id
JOIN     address   AS address
ON       address.address_id = cust.address_id
JOIN     city      AS city
ON       address.city_id = city.city_id
JOIN     country   AS country
ON       country.country_id = city.country_id
JOIN     table_1
ON       table_1.country = country.country
GROUP BY 1, 4, 2
ORDER BY 4 DESC, 1, 3 DESC

/*3. What are categories and titles of films with top 25% unit price (total amounts paid / number of times rented) and average unit price across each of such category?*/


WITH table_1 AS
(
             SELECT film.title                                              AS Title,
                   Count(*)                                                 AS Total_Rented,
                   Sum(pmt.amount)                                          AS Total_Paid,
                   Sum(pmt.amount) / Count(*)                               AS Unit_Paid,
                   Ntile(5) OVER (ORDER BY Sum(pmt.amount) / Count(*) DESC) AS quartile
             FROM   film      AS film
             JOIN   inventory AS inv
             ON     film.film_id = inv.film_id
             JOIN   rental    AS rent
             ON     rent.inventory_id = inv.inventory_id
             JOIN   payment   AS pmt
             ON     pmt.rental_id = rent.rental_id
             GROUP  BY 1
             ORDER  BY 5),

     table_2 AS
(
            SELECT title
            FROM   table_1
            WHERE  quartile = 1)

SELECT cat.NAME                                    AS category,
       film.title                                  AS title,
       unit_paid,
       Avg(unit_paid) OVER (partition BY cat.NAME) AS average_unit
FROM   category      AS cat
JOIN   film_category AS film_cat
ON     cat.category_id = film_cat.category_id
JOIN   film          AS film
ON     film.film_id = film_cat.film_id
JOIN   table_2
ON     table_2.title = film.title
JOIN   table_1
ON     table_2.title = table_1.title
GROUP  BY 1, 2, 3
ORDER  BY 4 DESC, 3 DESC

/*4. Do most orders occur in certain weeks? Find the weeks within where more than 10% of total orders fall*/


WITH table_1 AS
(
             SELECT Date_part('week', rental_date) AS week_id,
                    Count(*)                       AS total_rented
             FROM   rental                         AS rent
             GROUP  BY 1
             ORDER  BY 2 DESC),

     table_2 AS
(            SELECT week_id,
                    total_rented,
                    Sum(total_rented) OVER (ORDER BY total_rented DESC) AS running_total,
                    Sum(total_rented) / (SELECT Count(*) FROM rental)   AS percent_total
             FROM   table_1
             GROUP  BY 1, 2
             HAVING Sum(total_rented) / (SELECT Count(*) FROM rental) >= 0.1
             ORDER  BY 2 DESC)

SELECT week_id,
       Date_trunc('week', rent.rental_date) AS week_start,
       total_rented,
       percent_total
FROM   rental                               AS rent
JOIN   table_2
ON     table_2.week_id = Date_part('week', rent.rental_date)
GROUP  BY 2, 1, 3, 4
ORDER  BY 3 DESC
