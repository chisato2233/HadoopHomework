#!/bin/bash
# ============================================
# 停止Hadoop集群
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 停止Master节点
stop_master() {
    log_info "停止Master节点..."
    
    cd "$PROJECT_DIR/docker/compose"
    docker compose -f docker-compose-master.yml down
    
    log_info "Master节点已停止"
}

# 主函数
main() {
    log_info "============================================"
    log_info "  停止Hadoop集群"
    log_info "============================================"
    
    stop_master
    
    log_info "集群已停止"
}

main "$@"

