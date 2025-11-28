#!/bin/bash
# ============================================
# 构建Hadoop生态Docker镜像
# 需要先下载软件包到 docker/base/packages 目录
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOCKER_DIR="$PROJECT_DIR/docker/base"
PACKAGES_DIR="$DOCKER_DIR/packages"

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

# ============================================
# 软件包下载链接配置
# 每个包提供多个备选下载源
# ============================================

# JDK 8 - 使用Adoptium (Eclipse Temurin) OpenJDK
JDK_FILE="OpenJDK8U-jdk_x64_linux_hotspot_8u392b08.tar.gz"
JDK_URLS=(
    "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/8/jdk/x64/linux/OpenJDK8U-jdk_x64_linux_hotspot_8u392b08.tar.gz"
    "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u392-b08/OpenJDK8U-jdk_x64_linux_hotspot_8u392b08.tar.gz"
)

# Hadoop 3.3.6
HADOOP_FILE="hadoop-3.3.6.tar.gz"
HADOOP_URLS=(
    "https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz"
    "https://mirrors.aliyun.com/apache/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz"
    "https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz"
)

# ZooKeeper 3.8.4 (3.6.x已停止维护，使用3.8.x)
ZOOKEEPER_FILE="apache-zookeeper-3.8.4-bin.tar.gz"
ZOOKEEPER_URLS=(
    "https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-3.8.4/apache-zookeeper-3.8.4-bin.tar.gz"
    "https://mirrors.aliyun.com/apache/zookeeper/zookeeper-3.8.4/apache-zookeeper-3.8.4-bin.tar.gz"
    "https://archive.apache.org/dist/zookeeper/zookeeper-3.8.4/apache-zookeeper-3.8.4-bin.tar.gz"
)

# HBase 2.5.7 (2.4.x已停止维护，使用2.5.x)
HBASE_FILE="hbase-2.5.7-bin.tar.gz"
HBASE_URLS=(
    "https://mirrors.tuna.tsinghua.edu.cn/apache/hbase/2.5.7/hbase-2.5.7-bin.tar.gz"
    "https://mirrors.aliyun.com/apache/hbase/2.5.7/hbase-2.5.7-bin.tar.gz"
    "https://archive.apache.org/dist/hbase/2.5.7/hbase-2.5.7-bin.tar.gz"
)

# 尝试从多个源下载
download_with_fallback() {
    local filename=$1
    shift
    local urls=("$@")
    
    for url in "${urls[@]}"; do
        log_info "尝试下载: $url"
        if wget --timeout=30 --tries=2 -O "$PACKAGES_DIR/$filename" "$url" 2>/dev/null; then
            # 检查文件是否有效（大于1MB）
            local size=$(stat -f%z "$PACKAGES_DIR/$filename" 2>/dev/null || stat -c%s "$PACKAGES_DIR/$filename" 2>/dev/null)
            if [ "$size" -gt 1000000 ]; then
                log_info "✓ $filename 下载成功 ($(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes"))"
                return 0
            fi
        fi
        log_warn "× 下载失败，尝试下一个源..."
    done
    
    log_error "× $filename 所有下载源均失败"
    return 1
}

# 检查并下载软件包
download_packages() {
    log_step "检查并下载软件包..."
    
    mkdir -p "$PACKAGES_DIR"
    
    local failed=0
    
    # JDK
    if [ -f "$PACKAGES_DIR/$JDK_FILE" ]; then
        log_info "✓ $JDK_FILE 已存在"
    else
        download_with_fallback "$JDK_FILE" "${JDK_URLS[@]}" || ((failed++))
    fi
    
    # Hadoop
    if [ -f "$PACKAGES_DIR/$HADOOP_FILE" ]; then
        log_info "✓ $HADOOP_FILE 已存在"
    else
        download_with_fallback "$HADOOP_FILE" "${HADOOP_URLS[@]}" || ((failed++))
    fi
    
    # ZooKeeper
    if [ -f "$PACKAGES_DIR/$ZOOKEEPER_FILE" ]; then
        log_info "✓ $ZOOKEEPER_FILE 已存在"
    else
        download_with_fallback "$ZOOKEEPER_FILE" "${ZOOKEEPER_URLS[@]}" || ((failed++))
    fi
    
    # HBase
    if [ -f "$PACKAGES_DIR/$HBASE_FILE" ]; then
        log_info "✓ $HBASE_FILE 已存在"
    else
        download_with_fallback "$HBASE_FILE" "${HBASE_URLS[@]}" || ((failed++))
    fi
    
    if [ $failed -gt 0 ]; then
        log_error "有 $failed 个软件包下载失败"
        log_info ""
        log_info "请手动下载以下文件到: $PACKAGES_DIR/"
        log_info "----------------------------------------"
        [ ! -f "$PACKAGES_DIR/$JDK_FILE" ] && log_info "JDK: ${JDK_URLS[0]}"
        [ ! -f "$PACKAGES_DIR/$HADOOP_FILE" ] && log_info "Hadoop: ${HADOOP_URLS[0]}"
        [ ! -f "$PACKAGES_DIR/$ZOOKEEPER_FILE" ] && log_info "ZooKeeper: ${ZOOKEEPER_URLS[0]}"
        [ ! -f "$PACKAGES_DIR/$HBASE_FILE" ] && log_info "HBase: ${HBASE_URLS[0]}"
        exit 1
    fi
    
    log_info "所有软件包准备完成"
}

# 构建镜像
build_image() {
    log_step "开始构建Docker镜像..."
    
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
    log_step "保存镜像为tar文件..."
    
    OUTPUT_FILE="$PROJECT_DIR/hadoop-ecosystem.tar"
    
    docker save hadoop-ecosystem:latest -o "$OUTPUT_FILE"
    
    # 压缩
    gzip -f "$OUTPUT_FILE"
    
    log_info "镜像已保存到: ${OUTPUT_FILE}.gz"
    log_info "文件大小: $(du -h ${OUTPUT_FILE}.gz | cut -f1)"
}

# 显示手动下载信息
show_download_info() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  软件包手动下载地址${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo "如果自动下载失败，请手动下载以下文件:"
    echo ""
    echo "1. JDK 8 (Adoptium OpenJDK):"
    echo "   ${JDK_URLS[0]}"
    echo ""
    echo "2. Hadoop 3.3.6:"
    echo "   ${HADOOP_URLS[0]}"
    echo ""
    echo "3. ZooKeeper 3.8.4:"
    echo "   ${ZOOKEEPER_URLS[0]}"
    echo ""
    echo "4. HBase 2.5.7:"
    echo "   ${HBASE_URLS[0]}"
    echo ""
    echo "下载后放入: $PACKAGES_DIR/"
    echo -e "${CYAN}============================================${NC}"
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
    
    # 显示下载信息
    if [ "$1" = "--info" ] || [ "$1" = "-i" ]; then
        show_download_info
        exit 0
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
