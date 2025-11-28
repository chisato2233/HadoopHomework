#!/bin/bash
# ============================================
# 启动Hadoop集群（本地Docker部署）
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
COMPOSE_FILE="$PROJECT_DIR/docker/compose/docker-compose.yml"

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

# 启动集群容器
start_cluster() {
    log_step "启动Hadoop集群..."
    
    cd "$PROJECT_DIR/docker/compose"
    
    docker compose -f docker-compose.yml up -d
    
    log_info "所有容器已启动"
}

# 初始化HDFS目录
init_hdfs_dirs() {
    log_step "初始化HDFS目录..."
    
    # 等待HDFS就绪
    log_info "等待HDFS就绪（约30秒）..."
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
    " 2>/dev/null || log_warn "HDFS目录初始化失败，可能服务还未完全就绪"
    
    log_info "HDFS目录初始化完成"
}

# 验证集群状态
verify_cluster() {
    log_step "验证集群状态..."
    
    echo ""
    echo "=========================================="
    echo "  运行中的容器"
    echo "=========================================="
    docker compose -f "$COMPOSE_FILE" ps
    
    echo ""
    echo "=========================================="
    echo "  HDFS状态"
    echo "=========================================="
    docker exec hadoop1 hdfs dfsadmin -report 2>/dev/null | head -20 || echo "HDFS正在启动..."
    
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
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  集群启动完成！Web UI访问地址：${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "  HDFS NameNode:     http://localhost:9870"
    echo -e "  YARN ResourceMgr:  http://localhost:8088"
    echo -e "  HBase Master:      http://localhost:16010"
    echo -e "  Hive WebUI:        http://localhost:10002"
    echo -e "  JobHistory:        http://localhost:19888"
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "  进入主节点: docker exec -it hadoop1 bash"
    echo -e "  进入从节点: docker exec -it hadoop2 bash"
    echo -e "            docker exec -it hadoop3 bash"
    echo -e "${GREEN}============================================${NC}"
}

# 主函数
main() {
    log_info "============================================"
    log_info "  Hadoop集群启动脚本（本地Docker部署）"
    log_info "============================================"
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker Desktop"
        exit 1
    fi
    
    # 检查Docker服务
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请启动Docker Desktop"
        exit 1
    fi
    
    # 检查镜像是否存在
    if ! docker images | grep -q "hadoop-ecosystem"; then
        log_error "镜像 hadoop-ecosystem:latest 不存在"
        log_info "请先运行 build-image.sh 构建镜像"
        exit 1
    fi
    
    start_cluster
    
    # 等待服务启动
    log_info "等待服务启动（约60秒）..."
    sleep 60
    
    init_hdfs_dirs
    verify_cluster
    show_access_info
}

main "$@"
