#!/bin/bash
# ============================================
# 启动Hadoop集群
# 在Master ECS上执行
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 配置文件
ENV_FILE="$PROJECT_DIR/scripts/deploy/.env"

# 加载环境变量
load_env() {
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        log_info "环境变量已加载"
    else
        log_warn "环境变量文件不存在，使用默认配置"
        # 默认配置
        export MASTER_IP="127.0.0.1"
        export SLAVE1_IP="127.0.0.1"
        export SLAVE2_IP="127.0.0.1"
    fi
}

# 启动Master节点容器
start_master() {
    log_step "启动Master节点..."
    
    cd "$PROJECT_DIR/docker/compose"
    
    docker compose -f docker-compose-master.yml up -d
    
    log_info "Master节点容器已启动"
}

# 等待服务就绪
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    local max_attempts=30
    local attempt=1
    
    log_info "等待 $service ($host:$port) 就绪..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_info "$service 已就绪"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "$service 启动超时"
    return 1
}

# 初始化HDFS目录
init_hdfs_dirs() {
    log_step "初始化HDFS目录..."
    
    # 等待HDFS就绪
    sleep 30
    
    docker exec hadoop1 bash -c "
        # 创建用户目录
        hdfs dfs -mkdir -p /user/hadoop
        hdfs dfs -mkdir -p /user/hadoop/raw_logs
        hdfs dfs -mkdir -p /user/hadoop/cleaned_data
        hdfs dfs -mkdir -p /user/hadoop/output
        
        # 创建Hive目录
        hdfs dfs -mkdir -p /user/hive/warehouse
        hdfs dfs -chmod -R 777 /user/hive
        
        # 创建HBase目录
        hdfs dfs -mkdir -p /hbase
        hdfs dfs -chmod -R 777 /hbase
        
        echo 'HDFS目录初始化完成'
        hdfs dfs -ls /user
    "
    
    log_info "HDFS目录初始化完成"
}

# 验证集群状态
verify_cluster() {
    log_step "验证集群状态..."
    
    echo ""
    echo "=========================================="
    echo "  HDFS状态"
    echo "=========================================="
    docker exec hadoop1 hdfs dfsadmin -report 2>/dev/null | head -20
    
    echo ""
    echo "=========================================="
    echo "  YARN状态"
    echo "=========================================="
    docker exec hadoop1 yarn node -list 2>/dev/null || echo "YARN正在启动..."
    
    echo ""
    echo "=========================================="
    echo "  ZooKeeper状态"
    echo "=========================================="
    docker exec hadoop1 zkServer.sh status 2>/dev/null || echo "ZooKeeper正在启动..."
    
    echo ""
    echo "=========================================="
    echo "  HBase状态"
    echo "=========================================="
    docker exec hadoop1 bash -c 'echo "status" | hbase shell -n 2>/dev/null' || echo "HBase正在启动..."
}

# 显示访问信息
show_access_info() {
    local master_ip=${MASTER_IP:-"localhost"}
    
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  集群启动完成！Web UI访问地址：${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "  HDFS NameNode:     http://${master_ip}:9870"
    echo -e "  YARN ResourceMgr:  http://${master_ip}:8088"
    echo -e "  HBase Master:      http://${master_ip}:16010"
    echo -e "  Hive WebUI:        http://${master_ip}:10002"
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "  进入容器: docker exec -it hadoop1 bash"
    echo -e "${GREEN}============================================${NC}"
}

# 主函数
main() {
    log_info "============================================"
    log_info "  Hadoop集群启动脚本"
    log_info "============================================"
    
    load_env
    start_master
    
    # 等待服务启动
    log_info "等待服务启动（约60秒）..."
    sleep 60
    
    init_hdfs_dirs
    verify_cluster
    show_access_info
}

main "$@"

