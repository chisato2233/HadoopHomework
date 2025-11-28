# ============================================
# 构建Hadoop生态Docker镜像
# PowerShell版本 - Windows本地部署
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
    Write-Host "用法: .\build-image.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -Help       显示帮助信息"
    Write-Host "  -NoCache    不使用缓存重新构建"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\build-image.ps1              # 构建镜像"
    Write-Host "  .\build-image.ps1 -NoCache     # 清除缓存重新构建"
}

# 构建镜像
function Build-Image {
    Write-Step "开始构建Docker镜像..."
    Write-Info "镜像将自动从清华镜像站下载以下组件:"
    Write-Host "  - JDK 8 (Adoptium OpenJDK)"
    Write-Host "  - Hadoop 3.3.6"
    Write-Host "  - ZooKeeper 3.8.4"
    Write-Host "  - HBase 2.5.7"
    Write-Host ""
    Write-Warn "首次构建需要下载约2GB文件，请确保网络畅通"
    Write-Host ""
    
    Push-Location $DockerDir
    try {
        if ($NoCache) {
            Write-Warn "使用 -NoCache 模式，将重新下载所有组件"
            docker build --no-cache --progress=plain -t hadoop-ecosystem:latest .
        } else {
            docker build --progress=plain -t hadoop-ecosystem:latest .
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Info "============================================"
            Write-Info "  镜像构建成功: hadoop-ecosystem:latest"
            Write-Info "============================================"
            docker images | Select-String "hadoop-ecosystem"
        } else {
            Write-Err "镜像构建失败"
            exit 1
        }
    } finally {
        Pop-Location
    }
}

# 主函数
function Main {
    Write-Info "============================================"
    Write-Info "  Hadoop生态Docker镜像构建脚本"
    Write-Info "============================================"
    
    if ($Help) {
        Show-Help
        exit 0
    }
    
    # 检查Docker
    try {
        $null = Get-Command docker -ErrorAction Stop
    } catch {
        Write-Err "Docker未安装，请先安装Docker Desktop"
        exit 1
    }
    
    # 检查Docker服务
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Docker服务未运行，请启动Docker Desktop"
        exit 1
    }
    
    Build-Image
    
    Write-Host ""
    Write-Info "============================================"
    Write-Info "  构建完成！"
    Write-Info "============================================"
    Write-Host ""
    Write-Info "下一步: 运行 .\start-cluster.ps1 启动集群"
}

Main

