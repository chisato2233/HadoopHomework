# ============================================
# 构建 Hadoop 生态 Docker 镜像
# PowerShell 版本 - Windows/WSL 本地部署
# ============================================

param(
    [switch]$Help,
    [switch]$NoCache
)

$ErrorActionPreference = "Stop"

# 获取脚本和项目目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$DockerDir = Join-Path $ProjectDir "docker\base"

# 颜色输出函数
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Step { Write-Host "[STEP] $args" -ForegroundColor Cyan }

# 显示帮助
function Show-Help {
    Write-Host ""
    Write-Host "构建 Hadoop 生态 Docker 镜像" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "用法: .\build-image.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -Help       显示帮助信息"
    Write-Host "  -NoCache    不使用缓存重新构建（完整重建）"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\build-image.ps1              # 使用缓存构建（快速）"
    Write-Host "  .\build-image.ps1 -NoCache     # 完整重建（慢）"
    Write-Host ""
}

# 检查 Docker 环境
function Test-DockerEnvironment {
    Write-Step "检查 Docker 环境..."

    # 检查 Docker 命令
    try {
        $null = Get-Command docker -ErrorAction Stop
    } catch {
        Write-Err "Docker 未安装！"
        Write-Host ""
        Write-Host "请安装 Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
        exit 1
    }

    # 检查 Docker 服务
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Docker 服务未运行！"
        Write-Host ""
        Write-Host "请启动 Docker Desktop 并等待其完全启动" -ForegroundColor Yellow
        exit 1
    }

    Write-Info "Docker 环境正常"
}

# 构建镜像
function Build-Image {
    Write-Step "开始构建 Docker 镜像..."
    Write-Host ""
    Write-Host "  镜像包含以下组件:" -ForegroundColor White
    Write-Host "    - OpenJDK 8"
    Write-Host "    - Hadoop 3.3.6"
    Write-Host "    - ZooKeeper 3.8.4"
    Write-Host "    - HBase 2.5.7"
    Write-Host "    - Hive 3.1.3"
    Write-Host "    - MySQL JDBC Driver 8.0.28"
    Write-Host ""
    Write-Warn "首次构建需要下载约 2.5GB 文件，请确保网络畅通"
    Write-Host ""

    Push-Location $DockerDir
    try {
        $buildArgs = @("build", "--progress=plain", "-t", "hadoop-ecosystem:latest", ".")

        if ($NoCache) {
            Write-Warn "使用 --no-cache 模式，将重新下载所有组件..."
            $buildArgs = @("build", "--no-cache", "--progress=plain", "-t", "hadoop-ecosystem:latest", ".")
        }

        & docker @buildArgs

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Info "=========================================="
            Write-Info "  镜像构建成功！"
            Write-Info "=========================================="
            Write-Host ""
            docker images hadoop-ecosystem --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
        } else {
            Write-Err "镜像构建失败！"
            Write-Host ""
            Write-Host "常见问题排查:" -ForegroundColor Yellow
            Write-Host "  1. 网络问题：尝试配置 Docker 镜像加速"
            Write-Host "  2. 磁盘空间不足：清理 Docker 缓存 (docker system prune)"
            Write-Host "  3. 内存不足：增加 Docker Desktop 内存分配"
            exit 1
        }
    } finally {
        Pop-Location
    }
}

# 主函数
function Main {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Hadoop 生态 Docker 镜像构建工具" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($Help) {
        Show-Help
        exit 0
    }

    Test-DockerEnvironment
    Build-Image

    Write-Host ""
    Write-Info "=========================================="
    Write-Info "  下一步：运行 .\start-cluster.ps1 启动集群"
    Write-Info "=========================================="
    Write-Host ""
}

Main
