-- Creating table that will hold data from CSV file
-- NOT NULL constraints are added to columns that must have a value for each record to be valid.
CREATE TABLE sales(
    region VARCHAR(50) NOT NULL,
    country VARCHAR(50) NOT NULL,
    item_type VARCHAR(50) NOT NULL,
    sales_channel CHAR(7) NOT NULL,
    order_priority CHAR(1) NOT NULL,
    order_date DATE NOT NULL,
    order_id SERIAL PRIMARY KEY,
    ship_date DATE NOT NULL,
    units_sold SMALLINT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    unit_cost NUMERIC(10, 2) NOT NULL,
    total_revenue NUMERIC(10, 2) NOT NULL,
    total_cost NUMERIC(10, 2) NOT NULL,
    total_profit NUMERIC(10, 2) NOT NULL
)

-- Importing the data from the CSV file
COPY sales(region, country, item_type, sales_channel, order_priority, 
    order_date, order_id, ship_date, units_sold, unit_price, 
    unit_cost, total_revenue, total_cost, total_profit)
FROM '/private/tmp/sales.csv'
DELIMITER ',' 
CSV HEADER; -- First line in CSV file contains column names. This tells PostgreSQL to skip the first line to avoid using name as data.


-- Checking if the import of the CSV worked
SELECT * FROM sales

-- Changing the original table from 1NF to 3NF
-- UNIQUE is used to avoid redudant values
-- regions table
CREATE TABLE regions (
    region_id SERIAL PRIMARY KEY,
    region_name VARCHAR(50) NOT NULL UNIQUE);

-- countries table with foreign key to regions table (countries depends on regions, so needs to be on a different table to avoid transitive dependency)
CREATE TABLE countries (
    country_id SERIAL PRIMARY KEY,
    country_name VARCHAR(50) NOT NULL UNIQUE,
    region_id INTEGER NOT NULL,
    FOREIGN KEY (region_id) REFERENCES regions(region_id));

-- item types table
CREATE TABLE item_types (
    item_type_id SERIAL PRIMARY KEY,
    item_type_name VARCHAR(50) NOT NULL UNIQUE);

-- sales channels table
CREATE TABLE sales_channels (
    channel_id SERIAL PRIMARY KEY,
    channel_name CHAR(7) NOT NULL UNIQUE);

-- orders with foreign keys to the country, item_types, and sales_channels tables
CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    country_id INTEGER NOT NULL,
    item_type_id INTEGER NOT NULL,
    channel_id INTEGER NOT NULL,
    order_priority CHAR(1) NOT NULL,
    order_date DATE NOT NULL,
    ship_date DATE NOT NULL,
    units_sold SMALLINT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    unit_cost NUMERIC(10, 2) NOT NULL, 
    total_revenue NUMERIC(10, 2) NOT NULL,
    total_cost NUMERIC(10, 2) NOT NULL,
    total_profit NUMERIC(10, 2) NOT NULL,
    FOREIGN KEY (country_id) REFERENCES countries(country_id),
    FOREIGN KEY (item_type_id) REFERENCES item_types(item_type_id),
    FOREIGN KEY (channel_id) REFERENCES sales_channels(channel_id));

-- Populating the item_types table
INSERT INTO item_types(item_type_name)
SELECT DISTINCT item_type
FROM sales;

-- Populating the sales_channels table
INSERT INTO sales_channels(channel_name)
SELECT DISTINCT sales_channel
FROM sales;

-- Populating the regions table
INSERT INTO regions(region_name)
SELECT DISTINCT region 
FROM sales;

-- Populating the countries table
INSERT INTO countries(country_name, region_id)
SELECT DISTINCT s.Country, r.region_id
FROM sales s
JOIN regions r ON s.region = r.region_name; -- joining with regions table connects each country to its correct region_id

-- Populating the orders table
INSERT INTO orders(
    order_id, country_id, item_type_id, channel_id,
    order_priority, order_date, ship_date,
    units_sold, unit_price, unit_cost,
    total_revenue, total_cost, total_profit)
SELECT 
    s.order_id,
    c.country_id,
    it.item_type_id,
    sc.channel_id,
    s.order_priority,
    s.order_date,
    s.ship_date,
    s.units_sold,
    s.unit_price,
    s.unit_cost,
    s.total_revenue,
    s.total_cost,
    s.total_profit
FROM  sales s
/*
The orders table needs foreign keys (country_id, item_type_id, channel_id).
The sales table contains only columns with text values (region, country, item_type, sales_channel).
Text columns from sales are joined with corresponding columns from each foreign key table.
Now the orders table can properly identify what value a foreign key represents.
*/
JOIN countries c ON s.country = c.country_name
-- Joining regions table with sales table and countries table so each country correctly links to its region.
JOIN regions r ON s.region = r.region_name AND c.region_id = r.region_id 
JOIN item_types it ON s.item_type = it.item_type_name
JOIN sales_channels sc ON s.sales_Channel = sc.channel_name

select * from orders;

-- Revenue by region and item type
-- 3NF
SELECT r.region_name, it.item_type_name, SUM(o.total_revenue) AS revenue
FROM orders o JOIN countries c ON o.country_id = c.country_id
JOIN regions r ON c.region_id = r.region_id
JOIN item_types it ON o.item_type_id = it.item_type_id
GROUP BY r.region_name, it.item_type_name
ORDER BY r.region_name, revenue DESC;

-- 2NF
SELECT region, Item_Type, SUM(Total_Revenue) AS Revenue
FROM sales
GROUP BY Region, Item_Type
ORDER BY Region, Revenue DESC;


-- Total 10 countries by profit
-- 3NF
SELECT c.country_name, SUM(o.total_profit) AS total_profit
FROM orders o
JOIN countries c ON o.country_id = c.country_id
GROUP BY c.country_name
ORDER BY total_profit DESC
LIMIT 10;

-- 2NF
SELECT Country, SUM(Total_Profit) AS Total_Profit
FROM sales
GROUP BY Country
ORDER BY Total_Profit DESC
LIMIT 10;


-- Count of orders and average units per order for sales channels
-- 3NF
SELECT sc.channel_name, COUNT(o.units_sold) AS order_count, ROUND(AVG(o.units_sold), 2) AS avg_units_per_order
FROM orders o JOIN sales_channels sc ON o.channel_id = sc.channel_id
GROUP BY sc.channel_name
ORDER BY avg_units_per_order DESC;

-- 2NF
SELECT Sales_Channel, COUNT(Units_Sold) AS Order_Count, ROUND(AVG(Units_Sold), 2) AS Avg_Units_Per_Order
FROM sales
GROUP BY Sales_Channel
ORDER BY Avg_Units_Per_Order DESC;
