# Hadoop生态基础镜像 (Ubuntu 22.04)
# 包含 JDK + Hadoop + ZooKeeper + HBase + Hive
FROM ubuntu:22.04

LABEL maintainer="hadoop-homework"
LABEL description="Hadoop Ecosystem Base Image"

# 避免交互式安装提示
ENV DEBIAN_FRONTEND=noninteractive

# ============================================
# 软件版本配置（集中管理，方便修改）
# ============================================
ENV HADOOP_VERSION=3.3.6
ENV ZOOKEEPER_VERSION=3.8.4
ENV HBASE_VERSION=2.5.7
ENV HIVE_VERSION=3.1.3

# 设置环境变量
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_HOME=/usr/local/hadoop
ENV ZOOKEEPER_HOME=/usr/local/zookeeper
ENV HBASE_HOME=/usr/local/hbase
ENV HIVE_HOME=/usr/local/hive
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HBASE_HOME/bin:$HIVE_HOME/bin

# ============================================
# 第一阶段：配置镜像源并安装基础工具 + JDK
# ============================================
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
        openjdk-8-jdk \
        openssh-server \
        openssh-client \
        vim \
        net-tools \
        iputils-ping \
        wget \
        curl \
        netcat \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# 第二阶段：配置SSH
# ============================================
RUN mkdir -p /var/run/sshd && \
    echo 'root:hadoop' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    echo "StrictHostKeyChecking no" >> /root/.ssh/config && \
    echo "UserKnownHostsFile /dev/null" >> /root/.ssh/config

# ============================================
# 第三阶段：创建目录
# ============================================
RUN mkdir -p /usr/local/src \
    /data/hadoop/tmp /data/hadoop/name /data/hadoop/data \
    /data/zookeeper/data /data/zookeeper/logs \
    /data/hbase

# ============================================
# 第四阶段：下载并安装 Hadoop
# ============================================
RUN cd /usr/local/src && \
    echo ">>> Downloading Hadoop ${HADOOP_VERSION}..." && \
    wget -q --show-progress \
        "https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
        -O hadoop.tar.gz && \
    tar -zxf hadoop.tar.gz -C /usr/local/ && \
    mv /usr/local/hadoop-${HADOOP_VERSION} /usr/local/hadoop && \
    rm hadoop.tar.gz && \
    echo ">>> Hadoop installed"

# ============================================
# 第五阶段：下载并安装 ZooKeeper (使用Apache Archive)
# ============================================
RUN cd /usr/local/src && \
    echo ">>> Downloading ZooKeeper ${ZOOKEEPER_VERSION}..." && \
    wget -q --show-progress \
        "https://archive.apache.org/dist/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz" \
        -O zookeeper.tar.gz && \
    tar -zxf zookeeper.tar.gz -C /usr/local/ && \
    mv /usr/local/apache-zookeeper-${ZOOKEEPER_VERSION}-bin /usr/local/zookeeper && \
    rm zookeeper.tar.gz && \
    echo ">>> ZooKeeper installed"

# ============================================
# 第六阶段：下载并安装 HBase (使用Apache Archive)
# ============================================
RUN cd /usr/local/src && \
    echo ">>> Downloading HBase ${HBASE_VERSION}..." && \
    wget -q --show-progress \
        "https://archive.apache.org/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz" \
        -O hbase.tar.gz && \
    tar -zxf hbase.tar.gz -C /usr/local/ && \
    mv /usr/local/hbase-${HBASE_VERSION} /usr/local/hbase && \
    rm hbase.tar.gz && \
    echo ">>> HBase installed"

# ============================================
# 第七阶段：下载并安装 Hive
# ============================================
RUN cd /usr/local/src && \
    echo ">>> Downloading Hive ${HIVE_VERSION}..." && \
    wget -q --show-progress \
        "https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz" \
        -O hive.tar.gz && \
    tar -zxf hive.tar.gz -C /usr/local/ && \
    mv /usr/local/apache-hive-${HIVE_VERSION}-bin /usr/local/hive && \
    rm hive.tar.gz && \
    # 下载 MySQL JDBC 驱动
    wget -q "https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar" \
        -O /usr/local/hive/lib/mysql-connector-java-8.0.28.jar && \
    echo ">>> Hive installed"

# ============================================
# 第八阶段：配置环境变量
# ============================================
RUN echo "export JAVA_HOME=$JAVA_HOME" >> /etc/profile && \
    echo 'export HADOOP_HOME=/usr/local/hadoop' >> /etc/profile && \
    echo 'export ZOOKEEPER_HOME=/usr/local/zookeeper' >> /etc/profile && \
    echo 'export HBASE_HOME=/usr/local/hbase' >> /etc/profile && \
    echo 'export HIVE_HOME=/usr/local/hive' >> /etc/profile && \
    echo 'export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HBASE_HOME/bin:$HIVE_HOME/bin' >> /etc/profile && \
    # 同样配置到 bashrc
    echo "export JAVA_HOME=$JAVA_HOME" >> ~/.bashrc && \
    echo 'export HADOOP_HOME=/usr/local/hadoop' >> ~/.bashrc && \
    echo 'export ZOOKEEPER_HOME=/usr/local/zookeeper' >> ~/.bashrc && \
    echo 'export HBASE_HOME=/usr/local/hbase' >> ~/.bashrc && \
    echo 'export HIVE_HOME=/usr/local/hive' >> ~/.bashrc && \
    echo 'export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HBASE_HOME/bin:$HIVE_HOME/bin' >> ~/.bashrc

# ============================================
# 第九阶段：配置Hadoop
# ============================================
RUN echo "export JAVA_HOME=$JAVA_HOME" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_NAMENODE_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_DATANODE_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_SECONDARYNAMENODE_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_RESOURCEMANAGER_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_NODEMANAGER_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# ============================================
# 第十阶段：配置HBase
# ============================================
RUN echo "export JAVA_HOME=$JAVA_HOME" >> $HBASE_HOME/conf/hbase-env.sh && \
    echo "export HBASE_MANAGES_ZK=false" >> $HBASE_HOME/conf/hbase-env.sh

# ============================================
# 第十一阶段：配置Hive
# ============================================
RUN echo "export JAVA_HOME=$JAVA_HOME" >> $HIVE_HOME/conf/hive-env.sh && \
    echo "export HADOOP_HOME=$HADOOP_HOME" >> $HIVE_HOME/conf/hive-env.sh && \
    echo "export HIVE_CONF_DIR=$HIVE_HOME/conf" >> $HIVE_HOME/conf/hive-env.sh

# ============================================
# 暴露端口
# ============================================
# SSH: 22
# HDFS: 9870(NameNode UI), 9000(HDFS), 9864(DataNode)
# YARN: 8088(ResourceManager UI), 8042(NodeManager)
# ZooKeeper: 2181(client), 2888(follower), 3888(election)
# HBase: 16000(Master), 16010(Master UI), 16020(RegionServer), 16030(RegionServer UI)
# Hive: 10000(HiveServer2), 10002(Hive WebUI), 9083(Metastore)
EXPOSE 22 2181 2888 3888 8088 8042 9000 9864 9870 16000 16010 16020 16030 10000 10002 9083

# 启动脚本
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
