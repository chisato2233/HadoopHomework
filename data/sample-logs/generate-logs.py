#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
电商用户行为日志生成器
生成符合项目要求的模拟用户行为数据
"""

import random
import time
import json
from datetime import datetime, timedelta

# 配置参数
NUM_USERS = 1000          # 用户数量
NUM_PRODUCTS = 500        # 商品数量
NUM_RECORDS = 100000      # 生成记录数量
OUTPUT_FILE = "user_behavior.log"

# 行为类型及其权重
ACTION_TYPES = {
    "click": 0.50,      # 点击
    "browse": 0.30,     # 浏览
    "cart": 0.15,       # 加购
    "order": 0.05       # 下单
}

# 商品类别
CATEGORIES = [
    "电子产品", "服装鞋帽", "家居家装", "美妆护肤", 
    "食品饮料", "图书音像", "母婴用品", "运动户外"
]

def generate_user_id():
    """生成用户ID: U + 6位数字"""
    return f"U{random.randint(100000, 999999)}"

def generate_product_id():
    """生成商品ID: P + 8位数字"""
    return f"P{random.randint(10000000, 99999999)}"

def generate_timestamp(days_range=30):
    """生成时间戳（最近N天内）"""
    now = datetime.now()
    random_days = random.uniform(0, days_range)
    random_time = now - timedelta(days=random_days)
    return int(random_time.timestamp() * 1000)  # 毫秒时间戳

def generate_duration(action_type):
    """根据行为类型生成停留时长（秒）"""
    if action_type == "click":
        return random.randint(1, 10)
    elif action_type == "browse":
        return random.randint(10, 300)
    elif action_type == "cart":
        return random.randint(5, 60)
    elif action_type == "order":
        return random.randint(30, 180)
    return 0

def weighted_choice(choices):
    """带权重的随机选择"""
    total = sum(choices.values())
    r = random.uniform(0, total)
    cumulative = 0
    for choice, weight in choices.items():
        cumulative += weight
        if r <= cumulative:
            return choice
    return list(choices.keys())[0]

def generate_record():
    """生成单条用户行为记录"""
    action_type = weighted_choice(ACTION_TYPES)
    
    record = {
        "user_id": generate_user_id(),
        "product_id": generate_product_id(),
        "action_type": action_type,
        "timestamp": generate_timestamp(),
        "duration": generate_duration(action_type),
        "category": random.choice(CATEGORIES),
        "platform": random.choice(["web", "ios", "android"]),
        "session_id": f"S{random.randint(1000000000, 9999999999)}"
    }
    
    return record

def generate_log_line(record):
    """生成日志行（制表符分隔格式）"""
    # 格式: user_id\tproduct_id\taction_type\ttimestamp\tduration\tcategory\tplatform\tsession_id
    return "\t".join([
        record["user_id"],
        record["product_id"],
        record["action_type"],
        str(record["timestamp"]),
        str(record["duration"]),
        record["category"],
        record["platform"],
        record["session_id"]
    ])

def generate_json_line(record):
    """生成JSON格式日志行"""
    return json.dumps(record, ensure_ascii=False)

def add_dirty_data(lines, dirty_ratio=0.05):
    """添加脏数据用于测试数据清洗"""
    dirty_count = int(len(lines) * dirty_ratio)
    
    dirty_records = []
    for _ in range(dirty_count):
        dirty_type = random.choice(["invalid_action", "negative_duration", "missing_field", "malformed"])
        
        if dirty_type == "invalid_action":
            # 无效的行为类型
            dirty_records.append(f"U{random.randint(100000, 999999)}\tP{random.randint(10000000, 99999999)}\tINVALID\t{int(time.time()*1000)}\t10\t电子产品\tweb\tS123")
        elif dirty_type == "negative_duration":
            # 负数时长
            dirty_records.append(f"U{random.randint(100000, 999999)}\tP{random.randint(10000000, 99999999)}\tclick\t{int(time.time()*1000)}\t-5\t电子产品\tweb\tS123")
        elif dirty_type == "missing_field":
            # 缺少字段
            dirty_records.append(f"U{random.randint(100000, 999999)}\tP{random.randint(10000000, 99999999)}\tclick")
        elif dirty_type == "malformed":
            # 格式错误
            dirty_records.append(f"this is a malformed line @#$%")
    
    # 随机插入脏数据
    all_lines = lines + dirty_records
    random.shuffle(all_lines)
    
    return all_lines

def main():
    print(f"开始生成 {NUM_RECORDS} 条用户行为记录...")
    
    lines = []
    for i in range(NUM_RECORDS):
        record = generate_record()
        line = generate_log_line(record)
        lines.append(line)
        
        if (i + 1) % 10000 == 0:
            print(f"已生成 {i + 1} 条记录...")
    
    # 添加脏数据
    print("添加脏数据用于测试清洗逻辑...")
    lines = add_dirty_data(lines, dirty_ratio=0.05)
    
    # 写入文件
    print(f"写入文件: {OUTPUT_FILE}")
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write("# user_id\tproduct_id\taction_type\ttimestamp\tduration\tcategory\tplatform\tsession_id\n")
        for line in lines:
            f.write(line + "\n")
    
    print(f"完成！共生成 {len(lines)} 条记录（含约5%脏数据）")
    print(f"文件位置: {OUTPUT_FILE}")
    
    # 统计信息
    print("\n=== 数据统计 ===")
    action_counts = {"click": 0, "browse": 0, "cart": 0, "order": 0}
    for line in lines[:NUM_RECORDS]:  # 只统计正常数据
        parts = line.split("\t")
        if len(parts) >= 3 and parts[2] in action_counts:
            action_counts[parts[2]] += 1
    
    for action, count in action_counts.items():
        print(f"  {action}: {count} ({count/NUM_RECORDS*100:.1f}%)")

if __name__ == "__main__":
    main()

