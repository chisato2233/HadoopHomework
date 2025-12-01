# ============================================
# 停止 Hadoop 集群（本地 Docker 部署）
# PowerShell 版本 - Windows/WSL
# ============================================

param(
    [switch]$Help,
    [switch]$Clean,        # 清理数据卷
    [switch]$Force         # 强制清理，不询问确认
)

$ErrorActionPreference = "Stop"

# 获取脚本和项目目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ComposeDir = Join-Path $ProjectDir "docker\compose"

# 颜色输出函数
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Step { Write-Host "[STEP] $args" -ForegroundColor Cyan }

# 显示帮助
function Show-Help {
    Write-Host ""
    Write-Host "停止 Hadoop 集群" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "用法: .\stop-cluster.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -Help       显示帮助信息"
    Write-Host "  -Clean      停止集群并清理所有数据卷"
    Write-Host "  -Force      强制清理，不询问确认（与 -Clean 一起使用）"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\stop-cluster.ps1                # 停止集群（保留数据）"
    Write-Host "  .\stop-cluster.ps1 -Clean         # 停止并清理（需确认）"
    Write-Host "  .\stop-cluster.ps1 -Clean -Force  # 停止并强制清理"
    Write-Host ""
}

# 停止集群
function Stop-ClusterContainers {
    Write-Step "停止集群容器..."

    Push-Location $ComposeDir
    try {
        docker compose down

        if ($LASTEXITCODE -eq 0) {
            Write-Info "所有容器已停止"
        } else {
            Write-Warn "部分容器停止时出现问题"
        }
    } finally {
        Pop-Location
    }
}

# 清理数据卷
function Clear-DataVolumes {
    Write-Step "清理数据卷..."

    if (-not $Force) {
        Write-Host ""
        Write-Warn "警告：此操作将删除所有数据，包括："
        Write-Host "  - HDFS 文件系统数据"
        Write-Host "  - HBase 表数据"
        Write-Host "  - Hive 元数据"
        Write-Host "  - MySQL 数据库"
        Write-Host "  - Hue 用户配置"
        Write-Host ""

        $confirm = Read-Host "确认删除所有数据？输入 'yes' 确认"

        if ($confirm -ne "yes") {
            Write-Info "已取消清理操作"
            return
        }
    }

    Push-Location $ComposeDir
    try {
        docker compose down -v

        if ($LASTEXITCODE -eq 0) {
            Write-Info "数据卷已清理"
        }
    } finally {
        Pop-Location
    }
}

# 显示状态
function Show-Status {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  集群已停止" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  重新启动: .\start-cluster.ps1"
    Write-Host ""
}

# 主函数
function Main {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Hadoop 集群停止工具" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($Help) {
        Show-Help
        exit 0
    }

    Stop-ClusterContainers

    if ($Clean) {
        Clear-DataVolumes
    }

    Show-Status
}

Main
