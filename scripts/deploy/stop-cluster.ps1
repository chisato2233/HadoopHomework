# ============================================
# 停止Hadoop集群（本地Docker部署）
# PowerShell版本
# ============================================

param(
    [switch]$Help,
    [switch]$Clean
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

# 显示帮助
function Show-Help {
    Write-Host "用法: .\stop-cluster.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -Help       显示帮助信息"
    Write-Host "  -Clean      停止集群并清理所有数据卷"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\stop-cluster.ps1              # 停止集群（保留数据）"
    Write-Host "  .\stop-cluster.ps1 -Clean       # 停止集群并清理数据"
}

# 停止集群
function Stop-Cluster {
    Write-Info "停止Hadoop集群..."
    
    Push-Location $ComposeDir
    try {
        docker compose -f docker-compose.yml down
        Write-Info "集群已停止"
    } finally {
        Pop-Location
    }
}

# 清理数据卷
function Clear-Volumes {
    Write-Warn "警告：此操作将删除所有数据！"
    $confirm = Read-Host "确认删除所有数据卷？(y/n)"
    
    if ($confirm -eq "y" -or $confirm -eq "Y") {
        Push-Location $ComposeDir
        try {
            docker compose -f docker-compose.yml down -v
            Write-Info "数据卷已清理"
        } finally {
            Pop-Location
        }
    } else {
        Write-Info "取消清理"
    }
}

# 主函数
function Main {
    Write-Info "============================================"
    Write-Info "  停止Hadoop集群"
    Write-Info "============================================"
    
    if ($Help) {
        Show-Help
        exit 0
    }
    
    if ($Clean) {
        Stop-Cluster
        Clear-Volumes
    } else {
        Stop-Cluster
    }
}

Main

