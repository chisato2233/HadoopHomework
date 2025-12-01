# 电商用户行为全链路分析平台

## 📋 项目概述

基于 Hadoop 生态的电商用户行为分析平台，实现用户行为数据的采集、清洗、存储和分析。使用 Docker 容器化部署，支持在 Windows 本地机器上运行完整的 Hadoop 集群。

## 🏗️ 集群架构

```
┌───────────────────────────────────────────────────────────────────────┐
│                  本地 Docker 网络 (172.18.0.0/24)                      │
├────────────────┬────────────────┬────────────────┬────────────────────┤
│    hadoop1     │    hadoop2     │    hadoop3     │   mysql + hue      │
│  172.18.0.2    │  172.18.0.3    │  172.18.0.4    │ .10 / .20          │
│   (master)     │   (slave1)     │   (slave2)     │                    │
│                │                │                │                    │
│ NameNode       │ DataNode       │ DataNode       │ MySQL 5.7          │
│ ResourceManager│ NodeManager    │ NodeManager    │ (Hive Metastore)   │
│ ZooKeeper      │ ZooKeeper      │ ZooKeeper      │                    │
│ HBase Master   │ RegionServer   │ RegionServer   │ Hue 4.11           │
│ HiveServer2    │                │                │ (Web管理界面)       │
└────────────────┴────────────────┴────────────────┴────────────────────┘
```

## 🛠️ 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| OpenJDK | 8 | Java 运行环境 |
| Hadoop | 3.3.6 | 分布式存储与计算 |
| ZooKeeper | 3.8.4 | 分布式协调服务 |
| HBase | 2.5.7 | 列式数据库 |
| Hive | 3.1.3 | 数据仓库 |
| MySQL | 5.7 | Hive/Hue 元数据存储 |
| Hue | 4.11.0 | Web 管理界面 |
| Docker | latest | 容器化部署 |

## 📁 目录结构

```
HadoopHomework/
├── docker/                    # Docker 配置
│   ├── base/                  # 基础镜像
│   │   ├── Dockerfile
│   │   └── scripts/
│   │       └── entrypoint.sh  # 容器启动脚本
│   └── compose/               
│       └── docker-compose.yml # 集群编排配置
├── config/                    # Hadoop 生态配置文件
│   ├── hadoop/                # core-site, hdfs-site, yarn-site
│   ├── zookeeper/             # zoo.cfg
│   ├── hbase/                 # hbase-site.xml
│   ├── hive/                  # hive-site.xml
│   └── hue/                   # hue.ini
├── scripts/                   # 部署脚本
│   └── deploy/
│       ├── build-image.ps1    # 构建 Docker 镜像
│       ├── start-cluster.ps1  # 启动集群
│       └── stop-cluster.ps1   # 停止集群
├── mapreduce/                 # MapReduce 程序
├── data/                      # 测试数据
├── hql/                       # Hive SQL 脚本
└── docs/                      # 项目文档
```

## 🚀 快速开始

### 前置要求

- **Windows 10/11** + **Docker Desktop**
- Docker Desktop 设置中启用 **WSL2 后端**
- 内存建议 **16GB+**（集群运行需要较大内存）
- 磁盘空间 **20GB+**

### 一键部署（3步）

```powershell
# 1. 进入项目目录
cd D:\Code\MyCode\HadoopHomework

# 2. 构建镜像（首次约10-15分钟）
.\scripts\deploy\build-image.ps1

# 3. 启动集群（约2分钟）
.\scripts\deploy\start-cluster.ps1
```

> ⚠️ 如果遇到脚本执行策略问题：
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
> ```

### 停止集群

```powershell
# 停止集群（保留数据）
.\scripts\deploy\stop-cluster.ps1

# 停止集群并清理所有数据
.\scripts\deploy\stop-cluster.ps1 -Clean
```

## 📊 Web UI 访问

集群启动后，访问以下地址：

| 服务 | 地址 | 说明 |
|------|------|------|
| **Hue** | http://localhost:8888 | 📌 推荐！统一管理界面 |
| HDFS NameNode | http://localhost:9870 | 文件系统状态 |
| YARN ResourceManager | http://localhost:8088 | 任务调度状态 |
| HBase Master | http://localhost:16010 | HBase 状态 |
| JobHistory | http://localhost:19888 | 历史任务 |

### Hue 首次登录

首次访问 Hue 会要求创建管理员账户，直接设置用户名和密码即可。

## 👥 容器角色分配

| 容器名 | IP 地址 | 角色 |
|--------|---------|------|
| hadoop1 | 172.18.0.2 | NameNode, ResourceManager, ZK, HMaster, HiveServer2 |
| hadoop2 | 172.18.0.3 | DataNode, NodeManager, ZK, RegionServer |
| hadoop3 | 172.18.0.4 | DataNode, NodeManager, ZK, RegionServer |
| mysql-hive | 172.18.0.10 | Hive Metastore + Hue 数据库 |
| hue | 172.18.0.20 | Web 管理界面 |

## 🔧 常用命令

### 进入容器

```powershell
docker exec -it hadoop1 bash    # 主节点
docker exec -it hadoop2 bash    # 从节点1
docker exec -it hadoop3 bash    # 从节点2
```

### 查看集群状态

```bash
# 在 hadoop1 容器内执行

# 查看所有 Java 进程
jps

# 查看 HDFS 状态
hdfs dfsadmin -report

# 查看 YARN 节点
yarn node -list

# 查看 ZooKeeper 状态
zkServer.sh status

# 查看 HBase 状态
echo "status" | hbase shell -n
```

### HDFS 基础操作

```bash
# 查看 HDFS 目录
hdfs dfs -ls /

# 创建目录
hdfs dfs -mkdir -p /user/hadoop/input

# 上传文件
hdfs dfs -put local_file /user/hadoop/input/

# 下载文件
hdfs dfs -get /user/hadoop/output/result local_path
```

### Hive 操作

```bash
# 进入 Hive CLI
hive

# 或使用 beeline 连接
beeline -u jdbc:hive2://localhost:10000
```

### 运行 MapReduce 示例

```bash
# WordCount 示例
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
    wordcount /input /output
```

## ⚠️ 常见问题

### 1. 内存不足

集群运行需要较大内存，建议在 Docker Desktop 设置中分配至少 **12GB**。

### 2. 端口被占用

确保以下端口未被占用：
- 8888 (Hue)
- 9870 (HDFS)
- 8088 (YARN)
- 16010 (HBase)
- 3307 (MySQL，已避开默认3306)

### 3. 服务启动失败

```powershell
# 查看容器日志
docker logs hadoop1

# 重启集群
.\scripts\deploy\stop-cluster.ps1
.\scripts\deploy\start-cluster.ps1
```

### 4. 完全重置

```powershell
# 清理所有数据重新开始
.\scripts\deploy\stop-cluster.ps1 -Clean -Force
.\scripts\deploy\start-cluster.ps1
```

## 📝 License

MIT License
