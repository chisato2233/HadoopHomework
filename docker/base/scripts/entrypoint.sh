#!/bin/bash

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

# 等待网络就绪
sleep 3

# 根据角色执行不同操作
case $ROLE in
    "master")
        echo "[INFO] Starting as Master Node..."
        
        # 等待所有节点就绪
        echo "[INFO] Waiting for slave nodes..."
        sleep 10
        
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
        
        # 等待HDFS就绪
        sleep 10
        
        # 启动HBase
        echo "[INFO] Starting HBase..."
        $HBASE_HOME/bin/start-hbase.sh
        ;;
        
    "slave")
        echo "[INFO] Starting as Slave Node..."
        
        # 创建ZK myid文件
        echo $NODE_ID > /data/zookeeper/data/myid
        
        # 启动ZooKeeper
        echo "[INFO] Starting ZooKeeper..."
        $ZOOKEEPER_HOME/bin/zkServer.sh start
        
        # 从节点服务由Master通过SSH启动
        echo "[INFO] Slave node ready, waiting for master to start services..."
        ;;
esac

# 保持容器运行
echo "[INFO] Container is running. Press Ctrl+C to stop."
tail -f /dev/null

