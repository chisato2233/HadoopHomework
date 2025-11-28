# 电商用户行为全链路分析平台

## 📋 项目概述

基于 Hadoop 生态的电商用户行为分析平台，实现用户行为数据的采集、清洗、存储和分析。使用 Docker 容器化部署，支持在 Windows 本地机器上运行完整的 Hadoop 集群。

## 🏗️ 集群架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    本地 Docker 网络 (172.18.0.0/24)              │
├─────────────────┬─────────────────┬─────────────────────────────┤
│    hadoop1      │     hadoop2     │          hadoop3            │
│   172.18.0.2    │   172.18.0.3    │        172.18.0.4           │
│    (master)     │    (slave1)     │         (slave2)            │
│                 │                 │                             │
│ NameNode        │ DataNode        │ DataNode                    │
│ ResourceManager │ NodeManager     │ NodeManager                 │
│ ZooKeeper       │ ZooKeeper       │ ZooKeeper                   │
│ HBase Master    │ RegionServer    │ RegionServer                │
│ HiveServer2     │                 │                             │
│ MySQL(元数据)    │                 │                             │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

## 🛠️ 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| JDK | Adoptium OpenJDK 8u392 | Java运行环境 |
| Hadoop | 3.3.6 | 分布式存储与计算 |
| ZooKeeper | 3.8.4 | 分布式协调服务 |
| HBase | 2.5.7 | 列式数据库 |
| Hive | 3.1.3 | 数据仓库 |
| MySQL | 5.7 | Hive元数据存储 |
| Docker | latest | 容器化部署 |

## 📁 目录结构

```
HadoopHomework/
├── docker/                    # Docker 配置
│   ├── base/                  # 基础镜像 Dockerfile
│   │   ├── Dockerfile
│   │   └── scripts/
│   │       └── entrypoint.sh
│   └── compose/               # Docker Compose 配置
│       └── docker-compose.yml
├── config/                    # Hadoop生态配置文件
│   ├── hadoop/                # core-site, hdfs-site, yarn-site
│   ├── zookeeper/             # zoo.cfg
│   ├── hbase/                 # hbase-site.xml
│   └── hive/                  # hive-site.xml
├── scripts/                   # 部署脚本 (PowerShell)
│   └── deploy/
│       ├── build-image.ps1    # 构建Docker镜像
│       ├── start-cluster.ps1  # 启动集群
│       └── stop-cluster.ps1   # 停止集群
├── mapreduce/                 # MapReduce 程序
├── data/                      # 测试数据
│   └── sample-logs/
├── hql/                       # Hive SQL 脚本
├── docs/                      # 项目文档
└── visualization/             # 可视化
```

## 🚀 快速开始

### 前置要求

- **Windows 10/11** + **Docker Desktop**
- Docker Desktop 设置中启用 **WSL2 后端**
- 内存建议 **16GB+**（集群运行需要较大内存）
- 磁盘空间 **20GB+**

### 1. 构建 Docker 镜像

在 PowerShell 中执行：

```powershell
# 进入项目目录
cd D:\Code\MyCode\HadoopHomework

# 构建镜像
.\scripts\deploy\build-image.ps1
```

> ⏱️ 首次构建需要下载约 2GB 文件，请确保网络畅通

如果遇到脚本执行策略问题：
```powershell
# 临时允许执行脚本
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### 2. 启动集群

```powershell
.\scripts\deploy\start-cluster.ps1
```

### 3. 停止集群

```powershell
# 停止集群（保留数据）
.\scripts\deploy\stop-cluster.ps1

# 停止集群并清理所有数据
.\scripts\deploy\stop-cluster.ps1 -Clean
```

## 👥 Docker 容器角色分配

| 容器名 | 容器IP | 角色 |
|--------|--------|------|
| hadoop1 | 172.18.0.2 | NameNode, ResourceManager, ZK, HMaster, Hive |
| hadoop2 | 172.18.0.3 | DataNode, NodeManager, ZK, RegionServer |
| hadoop3 | 172.18.0.4 | DataNode, NodeManager, ZK, RegionServer |
| mysql-hive | 172.18.0.10 | Hive Metastore 数据库 |

## 📊 Web UI 访问

集群启动后，可以通过以下地址访问各服务的 Web UI：

| 服务 | 端口 | 地址 |
|------|------|------|
| HDFS NameNode | 9870 | http://localhost:9870 |
| YARN ResourceManager | 8088 | http://localhost:8088 |
| HBase Master | 16010 | http://localhost:16010 |
| Hive WebUI | 10002 | http://localhost:10002 |
| MapReduce JobHistory | 19888 | http://localhost:19888 |

## 🔧 常用命令

### 进入容器

```powershell
# 进入主节点
docker exec -it hadoop1 bash

# 进入从节点
docker exec -it hadoop2 bash
docker exec -it hadoop3 bash
```

### 查看集群状态

```bash
# 进入hadoop1容器后执行

# 查看HDFS状态
hdfs dfsadmin -report

# 查看YARN节点
yarn node -list

# 查看ZooKeeper状态
zkServer.sh status

# 查看HBase状态
echo "status" | hbase shell
```

### HDFS 基础操作

```bash
# 上传文件到HDFS
hdfs dfs -put local_file /user/hadoop/

# 查看HDFS目录
hdfs dfs -ls /user/hadoop/

# 下载文件
hdfs dfs -get /user/hadoop/file local_path
```

### 运行 MapReduce 任务

```bash
# 运行WordCount示例
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar wordcount /input /output
```

## ⚠️ 注意事项

1. **内存需求**：集群运行需要较大内存，建议在 Docker Desktop 设置中分配至少 12GB
2. **首次启动**：首次启动会自动格式化 HDFS，后续启动会保留数据
3. **端口占用**：确保本地端口 9870、8088、16010、10002、3306 等未被占用
4. **脚本执行策略**：如遇到 PowerShell 脚本无法执行，使用 `Set-ExecutionPolicy Bypass -Scope Process`

## 📝 License

MIT License
