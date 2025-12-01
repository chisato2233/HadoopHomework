# HBase 表结构设计文档

## 表名：user_behavior

### 1. 设计目标

存储电商用户行为数据，支持：
- 按用户查询历史行为
- 按时间范围查询
- 高并发写入

### 2. RowKey 设计

**格式**: `user_id|reverse_timestamp`

**示例**: `1001|9999999999999998`

**设计理由**:
| 设计点 | 说明 |
|--------|------|
| user_id 前缀 | 同一用户数据连续存储，支持用户维度前缀扫描 |
| 时间戳倒序 | 最新数据排在前面，查询最近行为更高效 |
| 分隔符 `\|` | 便于解析和范围查询 |

**倒序时间戳计算**: `Long.MAX_VALUE - timestamp`

### 3. 列族设计

**列族**: `info`（单列族设计）

**设计理由**:
- 所有字段访问模式一致，通常一起读写
- 减少 StoreFile 数量，提升读取效率
- 简化运维管理

### 4. 列设计

| 列名 | 类型 | 说明 |
|------|------|------|
| info:product_id | String | 商品ID |
| info:action_type | String | 行为类型: click/browse/cart/order |
| info:duration | Int | 停留时长（秒） |
| info:event_time | String | 事件时间 |

### 5. 预分区策略

**分区数**: 4个 Region

**分区键**: ['3', '5', '7']

**设计理由**:
- user_id 假设为纯数字，按首位数字分区
- 避免数据热点，均匀分布到各 RegionServer
- 分区数与节点数匹配（1 Master + 2 RegionServer）

**建表语句**:
```
create 'user_behavior', {NAME => 'info', VERSIONS => 1}, SPLITS => ['3', '5', '7']
```

### 6. 版本控制

**VERSIONS**: 1

只保留最新版本，节省存储空间。

### 7. 查询场景

| 场景 | 查询方式 |
|------|----------|
| 查询用户所有行为 | `scan 'user_behavior', {ROWPREFIXFILTER => 'user_id'}` |
| 查询用户最近N条 | `scan ... {LIMIT => N}` |
| 查询单条记录 | `get 'user_behavior', 'rowkey'` |

### 8. 数据量估算

| 指标 | 预估值 |
|------|--------|
| 日均写入量 | 100万条 |
| 单条数据大小 | ~100 bytes |
| 日均数据量 | ~100 MB |
| 月数据量 | ~3 GB |

