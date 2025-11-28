#!/bin/bash
# ============================================
# 停止Hadoop集群（本地Docker部署）
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 停止集群
stop_cluster() {
    log_info "停止Hadoop集群..."
    
    cd "$PROJECT_DIR/docker/compose"
    docker compose -f docker-compose.yml down
    
    log_info "集群已停止"
}

# 清理数据卷（可选）
clean_volumes() {
    log_warn "警告：此操作将删除所有数据！"
    read -p "确认删除所有数据卷？(y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        cd "$PROJECT_DIR/docker/compose"
        docker compose -f docker-compose.yml down -v
        log_info "数据卷已清理"
    else
        log_info "取消清理"
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  --clean        停止集群并清理所有数据卷"
    echo ""
    echo "示例:"
    echo "  $0              # 停止集群（保留数据）"
    echo "  $0 --clean      # 停止集群并清理数据"
}

# 主函数
main() {
    log_info "============================================"
    log_info "  停止Hadoop集群"
    log_info "============================================"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --clean)
                stop_cluster
                clean_volumes
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    stop_cluster
}

main "$@"
