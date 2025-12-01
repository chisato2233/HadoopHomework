-- ============================================
-- Hive 建表语句
-- 电商用户行为分析
-- ============================================

-- 创建数据库
CREATE DATABASE IF NOT EXISTS ecommerce;
USE ecommerce;

-- 原始日志外部表（映射HDFS原始数据）
CREATE EXTERNAL TABLE IF NOT EXISTS raw_user_behavior (
    user_id STRING,
    product_id STRING,
    action_type STRING,
    duration INT,
    event_time STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LOCATION '/user/hadoop/raw_logs'
TBLPROPERTIES ('skip.header.line.count'='2');

-- 清洗后数据表（ORC格式，高效存储）
CREATE TABLE IF NOT EXISTS cleaned_user_behavior (
    user_id STRING,
    product_id STRING,
    action_type STRING,
    duration INT,
    event_time TIMESTAMP
)
STORED AS ORC
LOCATION '/user/hadoop/cleaned_data';

-- 商品统计结果表
CREATE TABLE IF NOT EXISTS product_stats (
    product_id STRING,
    click_count INT,
    browse_count INT,
    cart_count INT,
    order_count INT,
    unique_users INT
)
STORED AS ORC;

-- 用户行为汇总表
CREATE TABLE IF NOT EXISTS user_behavior_summary (
    user_id STRING,
    total_actions INT,
    clicks INT,
    browses INT,
    carts INT,
    orders INT,
    total_duration INT
)
STORED AS ORC;

