#!/bin/bash
# ============================================
# 构建Hadoop生态Docker镜像
# 需要先下载软件包到 docker/base/packages 目录
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOCKER_DIR="$PROJECT_DIR/docker/base"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# 构建镜像
build_image() {
    log_step "开始构建Docker镜像..."
    log_info "镜像将自动从清华镜像站下载以下组件:"
    echo "  - JDK 8 (Adoptium OpenJDK)"
    echo "  - Hadoop 3.3.6"
    echo "  - ZooKeeper 3.8.4"
    echo "  - HBase 2.5.7"
    echo ""
    log_warn "首次构建需要下载约2GB文件，请确保网络畅通"
    echo ""
    
    cd "$DOCKER_DIR"
    
    # 构建镜像，显示详细输出
    docker build --progress=plain -t hadoop-ecosystem:latest .
    
    if [ $? -eq 0 ]; then
        log_info "============================================"
        log_info "  镜像构建成功: hadoop-ecosystem:latest"
        log_info "============================================"
        docker images | grep hadoop-ecosystem
    else
        log_error "镜像构建失败"
        exit 1
    fi
}

# 保存镜像为tar文件（用于分发到其他ECS）
save_image() {
    log_step "保存镜像为tar文件..."
    
    OUTPUT_FILE="$PROJECT_DIR/hadoop-ecosystem.tar"
    
    docker save hadoop-ecosystem:latest -o "$OUTPUT_FILE"
    
    # 压缩
    log_info "压缩镜像文件..."
    gzip -f "$OUTPUT_FILE"
    
    log_info "镜像已保存到: ${OUTPUT_FILE}.gz"
    log_info "文件大小: $(du -h ${OUTPUT_FILE}.gz | cut -f1)"
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -s, --save     构建后自动保存为tar.gz文件"
    echo "  --no-cache     不使用缓存重新构建"
    echo ""
    echo "示例:"
    echo "  $0              # 构建镜像"
    echo "  $0 -s           # 构建并保存为tar文件"
    echo "  $0 --no-cache   # 清除缓存重新构建"
}

# 主函数
main() {
    log_info "============================================"
    log_info "  Hadoop生态Docker镜像构建脚本"
    log_info "============================================"
    
    # 解析参数
    AUTO_SAVE=false
    NO_CACHE=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--save)
                AUTO_SAVE=true
                shift
                ;;
            --no-cache)
                NO_CACHE="--no-cache"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先运行 init-ecs.sh 安装Docker"
        exit 1
    fi
    
    # 检查Docker服务
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请执行: sudo systemctl start docker"
        exit 1
    fi
    
    # 如果有 --no-cache 参数
    if [ -n "$NO_CACHE" ]; then
        log_warn "使用 --no-cache 模式，将重新下载所有组件"
        cd "$DOCKER_DIR"
        docker build --no-cache --progress=plain -t hadoop-ecosystem:latest .
    else
        build_image
    fi
    
    # 保存镜像
    if [ "$AUTO_SAVE" = true ]; then
        save_image
    else
        echo ""
        read -p "是否保存镜像为tar文件用于分发到其他节点? (y/n): " SAVE_CHOICE
        if [ "$SAVE_CHOICE" = "y" ] || [ "$SAVE_CHOICE" = "Y" ]; then
            save_image
        fi
    fi
    
    log_info "============================================"
    log_info "  构建完成！"
    log_info "============================================"
    echo ""
    log_info "下一步: 使用 distribute-image.sh 将镜像分发到其他节点"
}

main "$@"
