#!/bin/bash
# ============================================
# Hadoop容器启动脚本
# ============================================

# 设置环境变量
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-8-openjdk-amd64}
export HADOOP_HOME=${HADOOP_HOME:-/usr/local/hadoop}
export ZOOKEEPER_HOME=${ZOOKEEPER_HOME:-/usr/local/zookeeper}
export HBASE_HOME=${HBASE_HOME:-/usr/local/hbase}
export HIVE_HOME=/usr/local/hive
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HBASE_HOME/bin:$HIVE_HOME/bin

# 启动SSH服务
/usr/sbin/sshd

# 根据节点角色启动服务
ROLE=${NODE_ROLE:-"slave"}
NODE_ID=${NODE_ID:-"1"}

echo "=========================================="
echo "  Node Role: $ROLE"
echo "  Node ID: $NODE_ID"
echo "  Hostname: $(hostname)"
echo "=========================================="

# 创建ZK myid文件
echo $NODE_ID > /data/zookeeper/data/myid

# 等待网络就绪
sleep 3

# 根据角色执行不同操作
case $ROLE in
    "master")
        echo "[INFO] Starting as Master Node..."

        # 等待从节点就绪
        echo "[INFO] Waiting for slave nodes..."
        sleep 15

        # 首次启动时格式化HDFS
        if [ ! -f /data/hadoop/initialized ]; then
            echo "[INFO] Formatting HDFS NameNode..."
            $HADOOP_HOME/bin/hdfs namenode -format -force
            touch /data/hadoop/initialized
        fi

        # 启动ZooKeeper
        echo "[INFO] Starting ZooKeeper..."
        $ZOOKEEPER_HOME/bin/zkServer.sh start

        # 等待ZK集群就绪
        sleep 5

        # 启动HDFS
        echo "[INFO] Starting HDFS..."
        $HADOOP_HOME/sbin/start-dfs.sh

        # 启动YARN
        echo "[INFO] Starting YARN..."
        $HADOOP_HOME/sbin/start-yarn.sh

        # 启动MapReduce历史服务器
        echo "[INFO] Starting JobHistory Server..."
        $HADOOP_HOME/bin/mapred --daemon start historyserver

        # 等待HDFS就绪
        sleep 10

        # 启动HBase
        echo "[INFO] Starting HBase..."
        $HBASE_HOME/bin/start-hbase.sh

        # 初始化并启动Hive（仅Master节点）
        if [ -d "$HIVE_HOME" ]; then
            echo "[INFO] Initializing Hive..."

            # 创建Hive所需的HDFS目录
            $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/hive/warehouse
            $HADOOP_HOME/bin/hdfs dfs -mkdir -p /tmp
            $HADOOP_HOME/bin/hdfs dfs -chmod -R 777 /user/hive
            $HADOOP_HOME/bin/hdfs dfs -chmod -R 777 /tmp

            # 首次启动时初始化Hive元数据
            if [ ! -f /data/hive_initialized ]; then
                echo "[INFO] Initializing Hive schema..."
                $HIVE_HOME/bin/schematool -dbType mysql -initSchema --verbose || true
                touch /data/hive_initialized
            fi

            # 启动HiveServer2
            echo "[INFO] Starting HiveServer2..."
            nohup $HIVE_HOME/bin/hive --service hiveserver2 > /data/hadoop/logs/hiveserver2.log 2>&1 &

            echo "[INFO] Hive started!"
        fi

        echo "[INFO] All services started!"
        ;;

    "slave")
        echo "[INFO] Starting as Slave Node..."

        # 启动ZooKeeper
        echo "[INFO] Starting ZooKeeper..."
        $ZOOKEEPER_HOME/bin/zkServer.sh start

        # 从节点的DataNode和NodeManager由Master通过SSH启动
        echo "[INFO] Slave node ready, waiting for master to start services..."

        # 等待Master节点启动HBase后，启动RegionServer
        echo "[INFO] Waiting for HBase Master to be ready (10s)..."
        sleep 10

        # 启动HBase RegionServer
        if [ -d "$HBASE_HOME" ]; then
            echo "[INFO] Starting HBase RegionServer..."
            $HBASE_HOME/bin/hbase-daemon.sh start regionserver
            echo "[INFO] HBase RegionServer started!"
        fi
        ;;
esac

# 显示进程状态
echo "[INFO] Running processes:"
jps

# 保持容器运行
echo "[INFO] Container is running. Press Ctrl+C to stop."
tail -f /dev/null
