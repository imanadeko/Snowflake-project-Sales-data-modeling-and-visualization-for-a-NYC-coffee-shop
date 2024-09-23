-- Create stores table
CREATE OR REPLACE TABLE stores (
    store_id NUMBER(5, 0) PRIMARY KEY,
    store_location VARCHAR(100)
);

-- Insert store details from the sales table into the stores table
INSERT INTO stores
SELECT DISTINCT store_id,
                    store_location
FROM sales;

-- Create product category table
CREATE OR REPLACE TABLE product_category (
    product_category_id NUMBER(5, 0) PRIMARY KEY,
    product_category VARCHAR(100)
);

-- Insert product category details from sales table
INSERT INTO product_category
SELECT ROW_NUMBER() OVER(ORDER BY product_category),
        product_category
FROM sales
GROUP BY product_category;

-- Create product_type table
CREATE OR REPLACE TABLE product_type (
    product_type_id NUMBER(5, 0) PRIMARY KEY,
    product_type VARCHAR(100)
);

-- Insert product type details from sales table
INSERT INTO product_type
SELECT ROW_NUMBER() OVER(ORDER BY product_type),
        product_type
FROM sales
GROUP BY product_type;

-- Add new columns: product_category_id and product_type_id to the sales table
ALTER TABLE sales
ADD COLUMN product_category_id NUMBER(5, 0);

ALTER TABLE sales
ADD COLUMN product_type_id NUMBER(5, 0);

-- Update product_category_id and product_type_id in sales table using their respective tables
UPDATE sales
SET product_category_id = pc.product_category_id
FROM product_category AS pc
WHERE sales.product_category = pc.product_category;

UPDATE sales
SET product_type_id = pt.product_type_id
FROM product_type AS pt
WHERE sales.product_type = pt.product_type;

-- Create product_category_id in product_type
ALTER TABLE product_type
ADD COLUMN product_category_id NUMBER(5, 0);

-- Update product_category_id for each product_type
UPDATE product_type AS pt
SET product_category_id = s.product_category_id
FROM sales AS s
WHERE pt.product_type = s.product_type;

-- Create date table
CREATE OR REPLACE TABLE date_table (
    date DATE PRIMARY KEY,
    year NUMBER(4, 0),
    quarter NUMBER(1, 0),
    month NUMBER(2, 0),
    day NUMBER(2, 0),
    day_of_week NUMBER(1),
    month_name VARCHAR(10),
    day_name VARCHAR(10)
);

-- Populate date_table with all dates in 2023
SET(start_date, end_date) = ('2023-01-01', '2024-01-01');
SET row_count = (SELECT
                DATEDIFF(DAY,
                    TO_DATE($start_date),
                    TO_DATE($end_date)
                        )
                );
                
INSERT INTO date_table
WITH cte AS(
    SELECT ROW_NUMBER() OVER(ORDER BY SEQ4()) - 1 AS row_number,
        DATEADD(DAY, row_number, $start_date)::DATE AS date
    FROM TABLE(GENERATOR(rowcount => $row_count))
    )
SELECT date,
        YEAR(date),
        QUARTER(date),
        MONTH(date),
        DAY(date),
        DAYOFWEEK(date),
        MONTHNAME(date),
        DAYNAME(date)
FROM cte;

-- Establish relationships between by adding foreign keys to the sales and product_type tables
ALTER TABLE sales
ADD FOREIGN KEY (transaction_date) REFERENCES date_table(date);

ALTER TABLE sales
ADD FOREIGN KEY (store_id) REFERENCES stores(store_id);

ALTER TABLE sales
ADD FOREIGN KEY (product_category_id) REFERENCES product_category(product_category_id);

ALTER TABLE product_type
ADD FOREIGN KEY (product_category_id) REFERENCES product_category(product_category_id);

-- Drop redundant columns from sales table
ALTER TABLE sales
DROP COLUMN store_location,
            product_id,
            product_category,
            product_type,
            product_type_id;



-- Number of sales made
SELECT COUNT(*) 
FROM sales;

-- Number of products sold
SELECT SUM(transaction_qty)
FROM sales;

-- Amount of revenue generated
SELECT ROUND(SUM(unit_price * transaction_qty))
FROM sales;

-- Calculating %MoM change in revenue for each store
WITH monthly_revenue AS (
SELECT MONTH(s.transaction_date) AS month,
        SUM(s.transaction_qty * s.unit_price) AS revenue
FROM sales AS s
JOIN stores AS st
ON s.store_id = st.store_id
WHERE st.store_location = "Hell\'s Kitchen" -- Filter for store location accordingly
GROUP BY month
ORDER BY month
)
SELECT month,
        ROUND(
        100 * (
        (revenue - LAG(revenue) OVER(ORDER BY month)) / 
        LAG(revenue) OVER(ORDER BY month)
        )) AS perc_mom_revenue_change
FROM monthly_revenue;
