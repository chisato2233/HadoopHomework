#!/bin/bash
# ============================================
# 阿里云ECS初始化脚本 (Ubuntu 22.04)
# 在每台ECS上执行，安装Docker和基础工具
# ============================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root用户执行此脚本: sudo ./init-ecs.sh"
        exit 1
    fi
}

# 配置阿里云镜像源
setup_aliyun_mirror() {
    log_info "配置阿里云APT镜像源..."
    
    # 备份原有配置
    cp /etc/apt/sources.list /etc/apt/sources.list.backup 2>/dev/null || true
    
    # 配置阿里云镜像
    cat > /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF

    # 更新软件包列表
    apt-get update
    
    log_info "APT镜像源配置完成"
}

# 安装基础工具
install_base_tools() {
    log_info "安装基础工具..."
    
    apt-get install -y \
        vim \
        wget \
        curl \
        git \
        net-tools \
        lsof \
        htop \
        unzip \
        tree \
        ca-certificates \
        gnupg \
        lsb-release \
        apt-transport-https \
        software-properties-common
    
    log_info "基础工具安装完成"
}

# 安装Docker
install_docker() {
    log_info "安装Docker..."
    
    # 检查Docker是否已安装
    if command -v docker &> /dev/null; then
        log_warn "Docker已安装，跳过安装步骤"
        docker --version
        return
    fi
    
    # 添加Docker官方GPG密钥（使用阿里云镜像）
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # 添加Docker仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新并安装Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 启动Docker并设置开机自启
    systemctl start docker
    systemctl enable docker
    
    log_info "Docker安装完成"
    docker --version
}

# 配置Docker镜像加速
configure_docker_mirror() {
    log_info "配置Docker镜像加速..."
    
    mkdir -p /etc/docker
    
    cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com",
        "https://registry.docker-cn.com"
    ],
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF

    # 重启Docker
    systemctl daemon-reload
    systemctl restart docker
    
    log_info "Docker镜像加速配置完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # 检查ufw是否安装
    if ! command -v ufw &> /dev/null; then
        apt-get install -y ufw
    fi
    
    # 开放必要端口
    PORTS=(
        22      # SSH
        2181    # ZooKeeper
        2888    # ZooKeeper
        3888    # ZooKeeper
        8088    # YARN
        8042    # NodeManager
        9000    # HDFS
        9870    # HDFS WebUI
        9864    # DataNode
        16000   # HBase Master
        16010   # HBase Master WebUI
        16020   # HBase RegionServer
        16030   # HBase RegionServer WebUI
        10000   # HiveServer2
        10002   # Hive WebUI
        3306    # MySQL
        19888   # JobHistory
    )
    
    for port in "${PORTS[@]}"; do
        ufw allow ${port}/tcp
    done
    
    # 允许Docker网络
    ufw allow from 172.16.0.0/12
    ufw allow from 172.18.0.0/16
    
    # 启用防火墙（如果未启用）
    echo "y" | ufw enable || true
    
    log_info "防火墙配置完成"
}

# 创建项目目录
create_project_dirs() {
    log_info "创建项目目录..."
    
    mkdir -p /opt/hadoop-project
    mkdir -p /data/hadoop/tmp
    mkdir -p /data/hadoop/name
    mkdir -p /data/hadoop/data
    mkdir -p /data/zookeeper/data
    mkdir -p /data/zookeeper/logs
    mkdir -p /data/hbase
    mkdir -p /data/mysql
    
    log_info "项目目录创建完成"
}

# 配置系统优化
optimize_system() {
    log_info "配置系统优化..."
    
    # 增加文件描述符限制
    cat >> /etc/security/limits.conf <<EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF

    # 内核参数优化
    cat >> /etc/sysctl.conf <<EOF
# Hadoop优化参数
vm.swappiness=10
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.ip_forward=1
EOF
    
    sysctl -p
    
    log_info "系统优化配置完成"
}

# 配置时区
configure_timezone() {
    log_info "配置时区..."
    
    timedatectl set-timezone Asia/Shanghai
    
    log_info "时区设置为: Asia/Shanghai"
}

# 配置主机名（可选）
configure_hostname() {
    local node_type=$1
    
    if [ -n "$node_type" ]; then
        hostnamectl set-hostname "$node_type"
        log_info "主机名设置为: $node_type"
    fi
}

# 显示系统信息
show_system_info() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  系统信息${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo "  操作系统: $(lsb_release -d | cut -f2)"
    echo "  内核版本: $(uname -r)"
    echo "  Docker版本: $(docker --version 2>/dev/null || echo '未安装')"
    echo "  内存: $(free -h | grep Mem | awk '{print $2}')"
    echo "  磁盘: $(df -h / | tail -1 | awk '{print $2}')"
    echo "  CPU: $(nproc) 核"
    echo -e "${GREEN}============================================${NC}"
}

# 主函数
main() {
    log_info "============================================"
    log_info "  阿里云ECS初始化脚本 (Ubuntu 22.04)"
    log_info "============================================"
    
    check_root
    setup_aliyun_mirror
    install_base_tools
    install_docker
    configure_docker_mirror
    configure_firewall
    create_project_dirs
    optimize_system
    configure_timezone
    
    # 可选：设置主机名
    # 用法: ./init-ecs.sh MainNode
    if [ -n "$1" ]; then
        configure_hostname "$1"
    fi
    
    show_system_info
    
    log_info "============================================"
    log_info "  初始化完成！"
    log_info "  建议重新登录以应用所有配置"
    log_info "============================================"
}

main "$@"
