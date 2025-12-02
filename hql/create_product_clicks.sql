USE ecommerce;

CREATE EXTERNAL TABLE IF NOT EXISTS product_clicks (
    product_id STRING,
    click_count INT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
LOCATION '/user/hadoop/output/product_clicks';

SHOW TABLES;

SELECT * FROM product_clicks;

