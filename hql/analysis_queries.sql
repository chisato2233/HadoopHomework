-- ============================================
-- Hive 数据分析查询
-- 电商用户行为分析
-- ============================================

USE ecommerce;

-- ============================================
-- 1. 商品点击量 TOP10
-- ============================================
SELECT
    product_id,
    COUNT(*) as click_count
FROM raw_user_behavior
WHERE action_type = 'click'
GROUP BY product_id
ORDER BY click_count DESC
LIMIT 10;

-- ============================================
-- 2. 用户行为转化漏斗
-- ============================================
SELECT
    action_type,
    COUNT(*) as action_count,
    COUNT(DISTINCT user_id) as user_count
FROM raw_user_behavior
GROUP BY action_type
ORDER BY
    CASE action_type
        WHEN 'click' THEN 1
        WHEN 'browse' THEN 2
        WHEN 'cart' THEN 3
        WHEN 'order' THEN 4
    END;

-- ============================================
-- 3. 转化率计算
-- ============================================
SELECT
    click_users,
    cart_users,
    order_users,
    ROUND(cart_users * 100.0 / click_users, 2) as click_to_cart_rate,
    ROUND(order_users * 100.0 / cart_users, 2) as cart_to_order_rate
FROM (
    SELECT
        COUNT(DISTINCT CASE WHEN action_type='click' THEN user_id END) as click_users,
        COUNT(DISTINCT CASE WHEN action_type='cart' THEN user_id END) as cart_users,
        COUNT(DISTINCT CASE WHEN action_type='order' THEN user_id END) as order_users
    FROM raw_user_behavior
) t;

-- ============================================
-- 4. 用户活跃度分析
-- ============================================
SELECT
    user_id,
    COUNT(*) as total_actions,
    SUM(CASE WHEN action_type='click' THEN 1 ELSE 0 END) as clicks,
    SUM(CASE WHEN action_type='browse' THEN 1 ELSE 0 END) as browses,
    SUM(CASE WHEN action_type='cart' THEN 1 ELSE 0 END) as carts,
    SUM(CASE WHEN action_type='order' THEN 1 ELSE 0 END) as orders,
    SUM(duration) as total_duration
FROM raw_user_behavior
GROUP BY user_id
ORDER BY total_actions DESC;

-- ============================================
-- 5. 商品综合热度排名
-- ============================================
SELECT
    product_id,
    SUM(CASE WHEN action_type='click' THEN 1 ELSE 0 END) as clicks,
    SUM(CASE WHEN action_type='browse' THEN 1 ELSE 0 END) as browses,
    SUM(CASE WHEN action_type='cart' THEN 1 ELSE 0 END) as carts,
    SUM(CASE WHEN action_type='order' THEN 1 ELSE 0 END) as orders,
    COUNT(DISTINCT user_id) as unique_users
FROM raw_user_behavior
GROUP BY product_id
ORDER BY clicks DESC, browses DESC;

-- ============================================
-- 6. 导入清洗后数据
-- ============================================
INSERT OVERWRITE TABLE cleaned_user_behavior
SELECT
    user_id,
    product_id,
    action_type,
    duration,
    CAST(event_time AS TIMESTAMP) as event_time
FROM raw_user_behavior
WHERE
    user_id IS NOT NULL
    AND product_id IS NOT NULL
    AND action_type IN ('click', 'browse', 'cart', 'order')
    AND duration >= 0;

-- ============================================
-- 7. 生成商品统计
-- ============================================
INSERT OVERWRITE TABLE product_stats
SELECT
    product_id,
    SUM(CASE WHEN action_type='click' THEN 1 ELSE 0 END),
    SUM(CASE WHEN action_type='browse' THEN 1 ELSE 0 END),
    SUM(CASE WHEN action_type='cart' THEN 1 ELSE 0 END),
    SUM(CASE WHEN action_type='order' THEN 1 ELSE 0 END),
    COUNT(DISTINCT user_id)
FROM cleaned_user_behavior
GROUP BY product_id;

-- ============================================
-- 8. 生成用户汇总
-- ============================================
INSERT OVERWRITE TABLE user_behavior_summary
SELECT
    user_id,
    COUNT(*),
    SUM(CASE WHEN action_type='click' THEN 1 ELSE 0 END),
    SUM(CASE WHEN action_type='browse' THEN 1 ELSE 0 END),
    SUM(CASE WHEN action_type='cart' THEN 1 ELSE 0 END),
    SUM(CASE WHEN action_type='order' THEN 1 ELSE 0 END),
    SUM(duration)
FROM cleaned_user_behavior
GROUP BY user_id;

