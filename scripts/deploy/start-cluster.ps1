# ============================================
# 启动 Hadoop 集群（本地 Docker 部署）
# PowerShell 版本 - Windows/WSL
# ============================================

param(
    [switch]$Help,
    [switch]$SkipWait     # 跳过等待，快速启动
)

$ErrorActionPreference = "Stop"

# 获取脚本和项目目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ComposeDir = Join-Path $ProjectDir "docker\compose"
$ComposeFile = Join-Path $ComposeDir "docker-compose.yml"

# 颜色输出函数
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Step { Write-Host "[STEP] $args" -ForegroundColor Cyan }

# 显示帮助
function Show-Help {
    Write-Host ""
    Write-Host "启动 Hadoop 集群" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "用法: .\start-cluster.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -Help       显示帮助信息"
    Write-Host "  -SkipWait   跳过等待服务就绪（快速启动）"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\start-cluster.ps1              # 正常启动并等待服务就绪"
    Write-Host "  .\start-cluster.ps1 -SkipWait    # 快速启动，不等待"
    Write-Host ""
}

# 检查 Docker 环境
function Test-DockerEnvironment {
    Write-Step "检查 Docker 环境..."

    try {
        $null = Get-Command docker -ErrorAction Stop
    } catch {
        Write-Err "Docker 未安装，请先安装 Docker Desktop"
        exit 1
    }

    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Docker 服务未运行，请启动 Docker Desktop"
        exit 1
    }

    Write-Info "Docker 环境正常"
}

# 检查镜像
function Test-Image {
    Write-Step "检查 Docker 镜像..."

    $imageExists = docker images hadoop-ecosystem --format "{{.Repository}}" 2>$null
    if (-not $imageExists) {
        Write-Err "镜像 hadoop-ecosystem:latest 不存在！"
        Write-Host ""
        Write-Host "请先运行: .\build-image.ps1" -ForegroundColor Yellow
        exit 1
    }

    Write-Info "镜像已就绪"
}

# 启动集群容器
function Start-ClusterContainers {
    Write-Step "启动集群容器..."

    Push-Location $ComposeDir
    try {
        docker compose up -d

        if ($LASTEXITCODE -ne 0) {
            Write-Err "容器启动失败！"
            exit 1
        }

        Write-Info "所有容器已启动"
    } finally {
        Pop-Location
    }
}

# 初始化 Hue 数据库
function Initialize-HueDatabase {
    Write-Step "初始化 Hue 数据库..."

    # 等待 MySQL 就绪
    $maxRetries = 30
    $retryCount = 0

    while ($retryCount -lt $maxRetries) {
        $result = docker exec mysql-hive mysqladmin -uroot -proot123 ping 2>$null
        if ($LASTEXITCODE -eq 0) {
            break
        }
        $retryCount++
        Start-Sleep -Seconds 2
    }

    if ($retryCount -ge $maxRetries) {
        Write-Warn "MySQL 启动超时，Hue 数据库初始化将在 Hue 首次访问时自动完成"
        return
    }

    # 创建 Hue 数据库和用户
    $sql = @"
CREATE DATABASE IF NOT EXISTS hue DEFAULT CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS 'hue'@'%' IDENTIFIED BY 'hue123';
GRANT ALL PRIVILEGES ON hue.* TO 'hue'@'%';
FLUSH PRIVILEGES;
"@

    docker exec mysql-hive mysql -uroot -proot123 -e $sql 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Info "Hue 数据库初始化完成"
    } else {
        Write-Warn "Hue 数据库可能已存在，跳过初始化"
    }
}

# 等待服务就绪
function Wait-ServicesReady {
    Write-Step "等待 Hadoop 服务启动..."
    Write-Host ""
    Write-Host "  服务启动顺序:" -ForegroundColor White
    Write-Host "    1. ZooKeeper (全部节点)"
    Write-Host "    2. HDFS (NameNode -> DataNodes)"
    Write-Host "    3. YARN (ResourceManager -> NodeManagers)"
    Write-Host "    4. HBase (Master -> RegionServers)"
    Write-Host "    5. Hive (HiveServer2)"
    Write-Host ""
    Write-Warn "首次启动需要约 90 秒，请耐心等待..."
    Write-Host ""

    # 进度条
    $totalSeconds = 90
    for ($i = 0; $i -lt $totalSeconds; $i++) {
        $percent = [int](($i / $totalSeconds) * 100)
        $bar = "=" * [int]($percent / 2) + " " * (50 - [int]($percent / 2))
        Write-Host "`r  [$bar] $percent% ($i/$totalSeconds 秒)" -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host "`r  [==================================================] 100%              "
    Write-Host ""
}

# 验证集群状态
function Test-ClusterStatus {
    Write-Step "验证集群状态..."
    Write-Host ""

    # 检查容器状态
    Write-Host "  容器状态:" -ForegroundColor White
    $containers = @("hadoop1", "hadoop2", "hadoop3", "mysql-hive", "hue")
    foreach ($container in $containers) {
        $status = docker inspect --format='{{.State.Status}}' $container 2>$null
        if ($status -eq "running") {
            Write-Host "    [OK] $container" -ForegroundColor Green
        } else {
            Write-Host "    [X]  $container ($status)" -ForegroundColor Red
        }
    }
    Write-Host ""

    # 检查 Hadoop 进程
    Write-Host "  Hadoop1 进程:" -ForegroundColor White
    $jps = docker exec hadoop1 jps 2>$null
    if ($jps) {
        $processes = @("NameNode", "ResourceManager", "HMaster", "RunJar")
        foreach ($proc in $processes) {
            if ($jps -match $proc) {
                Write-Host "    [OK] $proc" -ForegroundColor Green
            } else {
                Write-Host "    [--] $proc (启动中...)" -ForegroundColor Yellow
            }
        }
    }
    Write-Host ""
}

# 显示访问信息
function Show-AccessInfo {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  集群启动完成！" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Web UI 访问地址:" -ForegroundColor White
    Write-Host ""
    Write-Host "    Hue (管理界面):   http://localhost:8888" -ForegroundColor Cyan
    Write-Host "    HDFS NameNode:    http://localhost:9870"
    Write-Host "    YARN Manager:     http://localhost:8088"
    Write-Host "    HBase Master:     http://localhost:16010"
    Write-Host "    JobHistory:       http://localhost:19888"
    Write-Host ""
    Write-Host "  进入容器:" -ForegroundColor White
    Write-Host ""
    Write-Host "    docker exec -it hadoop1 bash    # 主节点"
    Write-Host "    docker exec -it hadoop2 bash    # 从节点1"
    Write-Host "    docker exec -it hadoop3 bash    # 从节点2"
    Write-Host ""
    Write-Host "  停止集群:" -ForegroundColor White
    Write-Host ""
    Write-Host "    .\stop-cluster.ps1              # 停止（保留数据）"
    Write-Host "    .\stop-cluster.ps1 -Clean       # 停止并清理数据"
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
}

# 主函数
function Main {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Hadoop 集群启动工具" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($Help) {
        Show-Help
        exit 0
    }

    Test-DockerEnvironment
    Test-Image
    Start-ClusterContainers
    Initialize-HueDatabase

    if (-not $SkipWait) {
        Wait-ServicesReady
        Test-ClusterStatus
    } else {
        Write-Warn "已跳过服务等待，请稍后手动检查服务状态"
    }

    Show-AccessInfo
}

Main
