# ============================================
# MapReduce 任务执行脚本
# 全部在 Docker 容器中编译和运行
# ============================================

param(
    [Parameter(Position=0)]
    [ValidateSet("build", "clean", "stats", "all")]
    [string]$Task = "all",

    [switch]$Help
)

# 禁用 PowerShell 将 stderr 当作错误
$ErrorActionPreference = "Continue"
$JarName = "ecommerce-analysis-1.0-SNAPSHOT.jar"

function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Step { Write-Host "[STEP] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

function Show-Help {
    Write-Host ""
    Write-Host "MapReduce 任务执行脚本（容器内编译运行）" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "用法: .\run-mapreduce.ps1 [任务]"
    Write-Host ""
    Write-Host "任务:"
    Write-Host "  build    编译打包（在容器内）"
    Write-Host "  clean    运行数据清洗任务"
    Write-Host "  stats    运行点击统计任务"
    Write-Host "  all      编译并运行所有任务（默认）"
    Write-Host ""
}

function Invoke-DockerCmd {
    param([string]$Cmd)
    # 合并 stdout 和 stderr，过滤警告
    $result = docker exec hadoop1 bash -c "$Cmd" 2>&1
    $result | ForEach-Object {
        $line = $_.ToString()
        if ($line -notmatch "^WARNING:" -and $line -notmatch "^SLF4J:" -and $line -notmatch "log4j") {
            Write-Host $line
        }
    }
    return $LASTEXITCODE
}

function Install-Maven {
    Write-Step "检查 Maven 环境..."

    $hasMaven = docker exec hadoop1 bash -c "which mvn 2>/dev/null" 2>$null
    if (-not $hasMaven) {
        Write-Info "安装 Maven（仅首次需要，约1分钟）..."
        docker exec hadoop1 bash -c "apt-get update -qq && apt-get install -y -qq maven" 2>&1 | Out-Null
        Write-Info "Maven 安装完成"
    } else {
        Write-Info "Maven 已安装"
    }
}

function Build-Jar {
    Write-Step "在容器中编译 MapReduce 项目..."

    Install-Maven

    Write-Info "编译中..."
    $output = docker exec hadoop1 bash -c "cd /opt/mapreduce && mvn clean package -DskipTests" 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Info "编译成功！"
        docker exec hadoop1 ls -lh /opt/mapreduce/target/$JarName 2>$null
    } else {
        Write-Err "编译失败！查看错误信息："
        $output | Select-Object -Last 30 | ForEach-Object { Write-Host $_ }
        exit 1
    }
}

function Run-CleanJob {
    Write-Step "运行数据清洗任务..."

    # 检查 JAR 是否存在
    $jarExists = docker exec hadoop1 bash -c "test -f /opt/mapreduce/target/$JarName && echo yes" 2>$null
    if ($jarExists -ne "yes") {
        Write-Warn "JAR 文件不存在，先编译..."
        Build-Jar
    }

    # 删除已存在的输出目录
    docker exec hadoop1 bash -c "hdfs dfs -rm -r -f /user/hadoop/cleaned_data 2>/dev/null" 2>&1 | Out-Null

    Write-Info "执行清洗任务..."
    $output = docker exec hadoop1 hadoop jar /opt/mapreduce/target/$JarName com.ecommerce.clean.LogCleanDriver /user/hadoop/raw_logs /user/hadoop/cleaned_data 2>&1
    $exitCode = $LASTEXITCODE

    # 显示输出，过滤无关警告
    $output | ForEach-Object {
        $line = $_.ToString()
        if ($line -notmatch "^WARNING:" -and $line -notmatch "^SLF4J:" -and $line -notmatch "log4j.properties") {
            Write-Host $line
        }
    }

    if ($exitCode -eq 0) {
        Write-Info "清洗任务完成！"
        Write-Host ""
        Write-Host "清洗后数据预览:" -ForegroundColor White
        docker exec hadoop1 bash -c "hdfs dfs -cat /user/hadoop/cleaned_data/part-m-00000 2>/dev/null | head -5"
    } else {
        Write-Err "清洗任务失败！"
    }
}

function Run-StatsJob {
    Write-Step "运行点击统计任务..."

    # 检查 JAR 是否存在
    $jarExists = docker exec hadoop1 bash -c "test -f /opt/mapreduce/target/$JarName && echo yes" 2>$null
    if ($jarExists -ne "yes") {
        Write-Warn "JAR 文件不存在，先编译..."
        Build-Jar
    }

    # 检查输入数据是否存在
    docker exec hadoop1 bash -c "hdfs dfs -test -d /user/hadoop/cleaned_data" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "清洗后数据不存在，先运行清洗任务..."
        Run-CleanJob
    }

    # 删除已存在的输出目录
    docker exec hadoop1 bash -c "hdfs dfs -rm -r -f /user/hadoop/output/product_clicks 2>/dev/null" 2>&1 | Out-Null

    Write-Info "执行统计任务..."
    $output = docker exec hadoop1 hadoop jar /opt/mapreduce/target/$JarName com.ecommerce.stats.ProductClickCount /user/hadoop/cleaned_data /user/hadoop/output/product_clicks 2>&1
    $exitCode = $LASTEXITCODE

    # 显示输出，过滤无关警告
    $output | ForEach-Object {
        $line = $_.ToString()
        if ($line -notmatch "^WARNING:" -and $line -notmatch "^SLF4J:" -and $line -notmatch "log4j.properties") {
            Write-Host $line
        }
    }

    if ($exitCode -eq 0) {
        Write-Info "统计任务完成！"
        Write-Host ""
        Write-Host "商品点击统计结果:" -ForegroundColor White
        docker exec hadoop1 bash -c "hdfs dfs -cat /user/hadoop/output/product_clicks/part-r-00000 2>/dev/null"
    } else {
        Write-Err "统计任务失败！"
    }
}

# 主逻辑
if ($Help) {
    Show-Help
    exit 0
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  MapReduce 任务执行（容器内）" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

switch ($Task) {
    "build" {
        Build-Jar
    }
    "clean" {
        Run-CleanJob
    }
    "stats" {
        Run-StatsJob
    }
    "all" {
        Build-Jar
        Write-Host ""
        Run-CleanJob
        Write-Host ""
        Run-StatsJob
    }
}

Write-Host ""
Write-Info "完成！"
Write-Host ""
Write-Host "查看 YARN 任务: http://localhost:8088" -ForegroundColor Gray
Write-Host "查看 HDFS 文件: http://localhost:9870" -ForegroundColor Gray
