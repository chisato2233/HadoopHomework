#!/bin/bash
# ============================================
# 分发Docker镜像到其他ECS节点
# 在Master ECS上执行
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

# 加载环境变量
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# 从节点列表
SLAVE_NODES=("${SLAVE1_IP:-}" "${SLAVE2_IP:-}")

# 镜像文件
IMAGE_FILE="$PROJECT_DIR/hadoop-ecosystem.tar.gz"

# 分发镜像
distribute_image() {
    local target_ip=$1
    
    if [ -z "$target_ip" ]; then
        return
    fi
    
    log_info "分发镜像到: $target_ip"
    
    # 复制镜像文件
    scp "$IMAGE_FILE" root@${target_ip}:/opt/
    
    # 在目标机器上加载镜像
    ssh root@${target_ip} "
        cd /opt
        gunzip -f hadoop-ecosystem.tar.gz
        docker load -i hadoop-ecosystem.tar
        rm -f hadoop-ecosystem.tar
        echo '镜像加载完成'
        docker images | grep hadoop-ecosystem
    "
    
    log_info "镜像分发完成: $target_ip"
}

# 分发配置文件
distribute_config() {
    local target_ip=$1
    
    if [ -z "$target_ip" ]; then
        return
    fi
    
    log_info "分发配置文件到: $target_ip"
    
    # 同步项目目录
    rsync -avz --exclude='*.tar*' --exclude='packages' \
        "$PROJECT_DIR/" root@${target_ip}:/opt/hadoop-project/
    
    log_info "配置文件分发完成: $target_ip"
}

# 主函数
main() {
    log_info "============================================"
    log_info "  Docker镜像分发脚本"
    log_info "============================================"
    
    # 检查镜像文件
    if [ ! -f "$IMAGE_FILE" ]; then
        log_error "镜像文件不存在: $IMAGE_FILE"
        log_info "请先运行 build-image.sh 构建镜像"
        exit 1
    fi
    
    # 分发到各节点
    for node in "${SLAVE_NODES[@]}"; do
        if [ -n "$node" ]; then
            distribute_image "$node"
            distribute_config "$node"
        fi
    done
    
    log_info "============================================"
    log_info "  分发完成！"
    log_info "============================================"
}

main "$@"

