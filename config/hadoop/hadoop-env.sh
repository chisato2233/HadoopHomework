# Hadoop 环境配置

# Java Home
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# 用户配置（以root用户运行）
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root

# 日志配置
export HADOOP_LOG_DIR=/data/hadoop/logs

