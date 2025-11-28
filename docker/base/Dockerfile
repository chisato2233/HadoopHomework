# Hadoop生态基础镜像 (Ubuntu 22.04)
# 包含 JDK + Hadoop + ZooKeeper + HBase
FROM ubuntu:22.04

LABEL maintainer="hadoop-homework"
LABEL description="Hadoop Ecosystem Base Image"

# 避免交互式安装提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置环境变量
ENV JAVA_HOME=/usr/local/jdk1.8.0_381
ENV HADOOP_HOME=/usr/local/hadoop
ENV ZOOKEEPER_HOME=/usr/local/zookeeper
ENV HBASE_HOME=/usr/local/hbase
ENV HIVE_HOME=/usr/local/hive
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HBASE_HOME/bin:$HIVE_HOME/bin

# 配置阿里云镜像源
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update

# 安装基础工具
RUN apt-get install -y \
    openssh-server \
    openssh-client \
    vim \
    net-tools \
    wget \
    curl \
    netcat \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 配置SSH
RUN mkdir -p /var/run/sshd && \
    echo 'root:hadoop' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 生成SSH密钥并配置免密登录
RUN ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    echo "StrictHostKeyChecking no" >> /root/.ssh/config && \
    echo "UserKnownHostsFile /dev/null" >> /root/.ssh/config

# 创建软件目录
RUN mkdir -p /usr/local/src /data/hadoop/tmp /data/hadoop/name /data/hadoop/data \
    /data/zookeeper/data /data/zookeeper/logs /data/hbase

# 复制安装包（需要提前下载到 packages 目录）
COPY packages/jdk-8u381-linux-x64.tar.gz /usr/local/src/
COPY packages/hadoop-3.3.6.tar.gz /usr/local/src/
COPY packages/apache-zookeeper-3.6.4-bin.tar.gz /usr/local/src/
COPY packages/hbase-2.4.17-bin.tar.gz /usr/local/src/

# 解压并安装
RUN cd /usr/local/src && \
    tar -zxf jdk-8u381-linux-x64.tar.gz -C /usr/local/ && \
    tar -zxf hadoop-3.3.6.tar.gz -C /usr/local/ && \
    mv /usr/local/hadoop-3.3.6 /usr/local/hadoop && \
    tar -zxf apache-zookeeper-3.6.4-bin.tar.gz -C /usr/local/ && \
    mv /usr/local/apache-zookeeper-3.6.4-bin /usr/local/zookeeper && \
    tar -zxf hbase-2.4.17-bin.tar.gz -C /usr/local/ && \
    mv /usr/local/hbase-2.4.17 /usr/local/hbase && \
    rm -rf /usr/local/src/*

# 配置环境变量
RUN echo 'export JAVA_HOME=/usr/local/jdk1.8.0_381' >> /etc/profile && \
    echo 'export HADOOP_HOME=/usr/local/hadoop' >> /etc/profile && \
    echo 'export ZOOKEEPER_HOME=/usr/local/zookeeper' >> /etc/profile && \
    echo 'export HBASE_HOME=/usr/local/hbase' >> /etc/profile && \
    echo 'export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HBASE_HOME/bin' >> /etc/profile && \
    echo 'export JAVA_HOME=/usr/local/jdk1.8.0_381' >> ~/.bashrc && \
    echo 'export HADOOP_HOME=/usr/local/hadoop' >> ~/.bashrc && \
    echo 'export ZOOKEEPER_HOME=/usr/local/zookeeper' >> ~/.bashrc && \
    echo 'export HBASE_HOME=/usr/local/hbase' >> ~/.bashrc && \
    echo 'export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HBASE_HOME/bin' >> ~/.bashrc

# 配置Hadoop环境
RUN echo "export JAVA_HOME=$JAVA_HOME" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_NAMENODE_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_DATANODE_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_SECONDARYNAMENODE_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_RESOURCEMANAGER_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_NODEMANAGER_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# 配置HBase环境
RUN echo "export JAVA_HOME=$JAVA_HOME" >> $HBASE_HOME/conf/hbase-env.sh && \
    echo "export HBASE_MANAGES_ZK=false" >> $HBASE_HOME/conf/hbase-env.sh

# 暴露端口
# SSH: 22
# HDFS: 9870(NameNode UI), 9000(HDFS), 9864(DataNode)
# YARN: 8088(ResourceManager UI), 8042(NodeManager)
# ZooKeeper: 2181(client), 2888(follower), 3888(election)
# HBase: 16000(Master), 16010(Master UI), 16020(RegionServer), 16030(RegionServer UI)
EXPOSE 22 2181 2888 3888 8088 8042 9000 9864 9870 16000 16010 16020 16030

# 启动脚本
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
