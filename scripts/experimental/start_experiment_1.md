# 实验一：电商用户行为数据全链路分析

## 📋 实验目标

完成用户行为数据的采集、清洗、存储和分析全流程：
- 使用 **MapReduce** 实现日志清洗与指标计算
- 设计合理的 **HBase** 表结构存储清洗后数据
- 使用 **Hive** 进行多维度查询分析

## 📊 评分标准（对照）

| 模块 | 任务 | 分值 |
|------|------|------|
| MapReduce | 日志清洗逻辑正确 | 5分 |
| MapReduce | 指标计算准确 | 10分 |
| MapReduce | 优化措施有效（Combiner等） | 5分 |
| MapReduce | 代码规范清晰 | 5分 |
| HBase | 表结构合理性 | 10分 |
| HBase | 数据导入成功 | 5分 |
| HBase | 查询功能实现 | 5分 |

---

## Step 1: 准备测试数据

### 任务
将用户行为日志上传到 HDFS

### 数据文件
- 本地路径: `data/sample-logs/user_behavior.log`
- HDFS路径: `/user/hadoop/raw_logs/`

### 操作命令
```powershell
# 创建 HDFS 目录并上传数据
docker exec hadoop1 bash -c "
hdfs dfs -mkdir -p /user/hadoop/raw_logs
hdfs dfs -mkdir -p /user/hadoop/cleaned_data
hdfs dfs -mkdir -p /user/hadoop/output
hdfs dfs -put /opt/data/sample-logs/user_behavior.log /user/hadoop/raw_logs/
"
```

### 验证
- 访问 HDFS Web UI: http://localhost:9870
- 或在 Hue Files 中查看 `/user/hadoop/raw_logs/`

---

## Step 2: MapReduce 数据清洗

### 任务
编写 MapReduce 程序实现：
1. 格式验证：检查字段完整性
2. 数据过滤：过滤 action_type 不合法的记录
3. 字段提取：提取有效字段输出

### 代码文件
- **Mapper**: `mapreduce/src/main/java/com/ecommerce/clean/LogCleanMapper.java`
- **Reducer**: `mapreduce/src/main/java/com/ecommerce/clean/LogCleanReducer.java`
- **Driver**: `mapreduce/src/main/java/com/ecommerce/clean/LogCleanDriver.java`

### 清洗规则
| 规则 | 说明 |
|------|------|
| 字段数量 | 必须为5个字段 |
| action_type | 仅允许: click, browse, cart, order |
| duration | 必须 >= 0 |
| user_id | 不能为空 |

### 运行命令
```bash
# 在 hadoop1 容器内执行
hadoop jar /opt/mapreduce/target/ecommerce-analysis.jar \
    com.ecommerce.clean.LogCleanDriver \
    /user/hadoop/raw_logs \
    /user/hadoop/cleaned_data
```

### 输出
- 清洗后数据: `/user/hadoop/cleaned_data/`

---

## Step 3: MapReduce 指标计算

### 任务
编写 MapReduce 程序计算：
1. 商品点击量 TOP10
2. 用户行为转化统计

### 代码文件
- **点击统计**: `mapreduce/src/main/java/com/ecommerce/stats/ProductClickCount.java`
- **转化统计**: `mapreduce/src/main/java/com/ecommerce/stats/UserConversion.java`

### 优化措施
- 使用 **Combiner** 减少 Shuffle 数据量
- 使用自定义 **Partitioner** 优化数据分布

### 运行命令
```bash
# 商品点击统计
hadoop jar /opt/mapreduce/target/ecommerce-analysis.jar \
    com.ecommerce.stats.ProductClickCount \
    /user/hadoop/cleaned_data \
    /user/hadoop/output/product_clicks

# 查看结果
hdfs dfs -cat /user/hadoop/output/product_clicks/part-r-00000
```

---

## Step 4: HBase 表设计

### 任务
设计 HBase 表结构存储用户行为数据

### 表设计文档
- 设计文档: `docs/hbase_table_design.md`

### 表结构
| 项目 | 设计 |
|------|------|
| 表名 | user_behavior |
| RowKey | `user_id\|reverse_timestamp` |
| 列族 | info |
| 列 | product_id, action_type, duration, event_time |
| 预分区 | 按 user_id 哈希，4个 Region |

### 操作脚本
- HBase Shell 命令: `hql/hbase_commands.txt`

### 创建表命令
```bash
docker exec -it hadoop1 hbase shell
# 然后执行 hql/hbase_commands.txt 中的命令
```

---

## Step 5: 数据导入 HBase

### 任务
将清洗后的数据导入 HBase

### 方式选择
1. **HBase Shell** - 少量数据测试
2. **MapReduce BulkLoad** - 大批量导入（推荐）
3. **Hive-HBase 集成** - 通过 Hive 操作

### 代码文件
- BulkLoad 程序: `mapreduce/src/main/java/com/ecommerce/hbase/HBaseImporter.java`

---

## Step 6: Hive 数据分析

### 任务
创建 Hive 表并进行多维度分析

### SQL 脚本
- 建表语句: `hql/create_tables.sql`
- 分析查询: `hql/analysis_queries.sql`

### 分析内容
1. 商品点击量排名
2. 用户行为转化漏斗
3. 转化率计算
4. 活跃用户分析

### 执行方式
```bash
# 方式1: Hue Web 界面（推荐）
# 访问 http://localhost:8888 → Editor → Hive

# 方式2: 命令行
docker exec -it hadoop1 hive -f /opt/hql/create_tables.sql
docker exec -it hadoop1 hive -f /opt/hql/analysis_queries.sql
```

---

## Step 7: HBase 查询验证

### 任务
验证 HBase 数据查询功能

### 查询场景
1. 查询指定用户的所有行为
2. 查询指定时间范围的数据
3. 统计用户行为次数

### 操作命令
参考 `hql/hbase_commands.txt` 中的查询部分

---

## 📁 相关文件清单

```
HadoopHomework/
├── data/sample-logs/
│   └── user_behavior.log          # 测试数据
├── mapreduce/src/main/java/com/ecommerce/
│   ├── clean/                     # 数据清洗 MapReduce
│   ├── stats/                     # 指标统计 MapReduce
│   └── hbase/                     # HBase 导入程序
├── hql/
│   ├── create_tables.sql          # Hive 建表语句
│   ├── analysis_queries.sql       # Hive 分析查询
│   └── hbase_commands.txt         # HBase Shell 命令
└── docs/
    └── hbase_table_design.md      # HBase 表设计文档
```

---

## ✅ 完成检查

- [ ] 测试数据已上传到 HDFS
- [ ] MapReduce 清洗程序运行成功
- [ ] MapReduce 指标计算完成
- [ ] HBase 表已创建
- [ ] 数据已导入 HBase
- [ ] Hive 分析查询正常
- [ ] HBase 查询功能验证通过
