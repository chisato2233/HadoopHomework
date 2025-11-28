# ============================================
# 启动Hadoop集群（本地Docker部署）
# PowerShell版本
# ============================================

$ErrorActionPreference = "Stop"

# 获取脚本和项目目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ComposeFile = Join-Path $ProjectDir "docker\compose\docker-compose.yml"
$ComposeDir = Join-Path $ProjectDir "docker\compose"

# 颜色输出函数
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Step { Write-Host "[STEP] $args" -ForegroundColor Cyan }

# 启动集群容器
function Start-Cluster {
    Write-Step "启动Hadoop集群..."
    
    Push-Location $ComposeDir
    try {
        docker compose -f docker-compose.yml up -d
        Write-Info "所有容器已启动"
    } finally {
        Pop-Location
    }
}

# 初始化HDFS目录
function Initialize-HdfsDirs {
    Write-Step "初始化HDFS目录..."
    Write-Info "等待HDFS就绪（约30秒）..."
    Start-Sleep -Seconds 30
    
    $initScript = @"
hdfs dfs -mkdir -p /user/hadoop
hdfs dfs -mkdir -p /user/hadoop/raw_logs
hdfs dfs -mkdir -p /user/hadoop/cleaned_data
hdfs dfs -mkdir -p /user/hadoop/output
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod -R 777 /user/hive
hdfs dfs -mkdir -p /hbase
hdfs dfs -chmod -R 777 /hbase
echo 'HDFS目录初始化完成'
hdfs dfs -ls /user
"@
    
    try {
        docker exec hadoop1 bash -c $initScript 2>$null
        Write-Info "HDFS目录初始化完成"
    } catch {
        Write-Warn "HDFS目录初始化失败，可能服务还未完全就绪"
    }
}

# 验证集群状态
function Test-ClusterStatus {
    Write-Step "验证集群状态..."
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor White
    Write-Host "  运行中的容器" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor White
    docker compose -f $ComposeFile ps
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor White
    Write-Host "  HDFS状态" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor White
    try {
        docker exec hadoop1 hdfs dfsadmin -report 2>$null | Select-Object -First 20
    } catch {
        Write-Host "HDFS正在启动..."
    }
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor White
    Write-Host "  YARN状态" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor White
    try {
        docker exec hadoop1 yarn node -list 2>$null
    } catch {
        Write-Host "YARN正在启动..."
    }
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor White
    Write-Host "  ZooKeeper状态" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor White
    try {
        docker exec hadoop1 zkServer.sh status 2>$null
    } catch {
        Write-Host "ZooKeeper正在启动..."
    }
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor White
    Write-Host "  HBase状态" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor White
    try {
        docker exec hadoop1 bash -c 'echo "status" | hbase shell -n' 2>$null
    } catch {
        Write-Host "HBase正在启动..."
    }
}

# 显示访问信息
function Show-AccessInfo {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  集群启动完成！Web UI访问地址：" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  HDFS NameNode:     http://localhost:9870"
    Write-Host "  YARN ResourceMgr:  http://localhost:8088"
    Write-Host "  HBase Master:      http://localhost:16010"
    Write-Host "  Hive WebUI:        http://localhost:10002"
    Write-Host "  JobHistory:        http://localhost:19888"
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  进入主节点: docker exec -it hadoop1 bash"
    Write-Host "  进入从节点: docker exec -it hadoop2 bash"
    Write-Host "              docker exec -it hadoop3 bash"
    Write-Host "============================================" -ForegroundColor Green
}

# 主函数
function Main {
    Write-Info "============================================"
    Write-Info "  Hadoop集群启动脚本（本地Docker部署）"
    Write-Info "============================================"
    
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
    
    # 检查镜像是否存在
    $imageExists = docker images | Select-String "hadoop-ecosystem"
    if (-not $imageExists) {
        Write-Err "镜像 hadoop-ecosystem:latest 不存在"
        Write-Info "请先运行 .\build-image.ps1 构建镜像"
        exit 1
    }
    
    Start-Cluster
    
    # 等待服务启动
    Write-Info "等待服务启动（约60秒）..."
    Start-Sleep -Seconds 60
    
    Initialize-HdfsDirs
    Test-ClusterStatus
    Show-AccessInfo
}

Main

