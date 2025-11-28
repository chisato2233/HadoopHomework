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
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 软件包下载链接（阿里云/清华镜像）
declare -A PACKAGES=(
    ["jdk-8u381-linux-x64.tar.gz"]="https://mirrors.huaweicloud.com/java/jdk/8u381-b09/jdk-8u381-linux-x64.tar.gz"
    ["hadoop-3.3.6.tar.gz"]="https://mirrors.aliyun.com/apache/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz"
    ["apache-zookeeper-3.6.4-bin.tar.gz"]="https://mirrors.aliyun.com/apache/zookeeper/zookeeper-3.6.4/apache-zookeeper-3.6.4-bin.tar.gz"
    ["hbase-2.4.17-bin.tar.gz"]="https://mirrors.aliyun.com/apache/hbase/2.4.17/hbase-2.4.17-bin.tar.gz"
)

# 检查并下载软件包
download_packages() {
    log_info "检查软件包..."
    
    PACKAGES_DIR="$DOCKER_DIR/packages"
    mkdir -p "$PACKAGES_DIR"
    
    for pkg in "${!PACKAGES[@]}"; do
        if [ -f "$PACKAGES_DIR/$pkg" ]; then
            log_info "✓ $pkg 已存在"
        else
            log_warn "× $pkg 不存在，开始下载..."
            wget -O "$PACKAGES_DIR/$pkg" "${PACKAGES[$pkg]}"
            
            if [ $? -eq 0 ]; then
                log_info "✓ $pkg 下载完成"
            else
                log_error "× $pkg 下载失败"
                log_info "请手动下载: ${PACKAGES[$pkg]}"
                log_info "并放置到: $PACKAGES_DIR/"
                exit 1
            fi
        fi
    done
    
    log_info "所有软件包准备完成"
}

# 构建镜像
build_image() {
    log_info "开始构建Docker镜像..."
    
    cd "$DOCKER_DIR"
    
    docker build -t hadoop-ecosystem:latest .
    
    if [ $? -eq 0 ]; then
        log_info "镜像构建成功: hadoop-ecosystem:latest"
    else
        log_error "镜像构建失败"
        exit 1
    fi
}

# 保存镜像为tar文件（用于分发到其他ECS）
save_image() {
    log_info "保存镜像为tar文件..."
    
    OUTPUT_FILE="$PROJECT_DIR/hadoop-ecosystem.tar"
    
    docker save hadoop-ecosystem:latest -o "$OUTPUT_FILE"
    
    # 压缩
    gzip -f "$OUTPUT_FILE"
    
    log_info "镜像已保存到: ${OUTPUT_FILE}.gz"
    log_info "文件大小: $(du -h ${OUTPUT_FILE}.gz | cut -f1)"
}

# 主函数
main() {
    log_info "============================================"
    log_info "  Hadoop生态Docker镜像构建脚本"
    log_info "============================================"
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装"
        exit 1
    fi
    
    download_packages
    build_image
    
    # 询问是否保存镜像
    read -p "是否保存镜像为tar文件用于分发? (y/n): " SAVE_IMAGE
    if [ "$SAVE_IMAGE" = "y" ] || [ "$SAVE_IMAGE" = "Y" ]; then
        save_image
    fi
    
    log_info "============================================"
    log_info "  构建完成！"
    log_info "============================================"
}

main "$@"

