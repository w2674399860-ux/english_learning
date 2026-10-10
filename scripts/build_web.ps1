<#
  构建 Flutter Web 并放进 backend_fastapi/static/，由后端同源托管（E-1）。

  用法（Windows PowerShell 5.1 或 PowerShell 7，在仓库根目录）：
    powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1

  可选参数：
    -ApiBaseUrl https://api.example.com
        前后端不同源时才需要。默认空串：请求走相对路径 /api/v1/...，
        由托管页面的同一个后端处理，任何地址（localhost、局域网 IP、正式域名）打开都可用，不涉及 CORS。

  构建选项：
    --no-web-resources-cdn  CanvasKit 从产物自带的 canvaskit/ 加载，不访问 Google CDN（gstatic）
    SHOW_GALLERY 不传        release 构建不包含组件展示页

  static/ 不入版本库（.gitignore）。容器化时先运行本脚本，再在 docker/ 下 docker compose build backend。
#>
param(
    [string]$ApiBaseUrl = ''
)
$ErrorActionPreference = 'Stop'

$repoRoot  = Split-Path -Parent $PSScriptRoot
$frontend  = Join-Path $repoRoot 'frontend_flutter'
$buildWeb  = Join-Path $frontend 'build\web'
$staticDir = Join-Path $repoRoot 'backend_fastapi\static'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw '找不到 flutter，请先安装 Flutter 并加入 PATH'
}

Push-Location $frontend
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get 失败' }

    flutter build web --release --no-web-resources-cdn "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'flutter build web 失败' }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath (Join-Path $buildWeb 'index.html'))) {
    throw "构建产物缺少 index.html：$buildWeb"
}

# 防误删：只清空确切的 backend_fastapi\static，路径不符就停止
$resolved = [System.IO.Path]::GetFullPath($staticDir)
if (-not $resolved.EndsWith('\backend_fastapi\static')) {
    throw "拒绝清空意外的路径：$resolved"
}
if (Test-Path -LiteralPath $resolved) {
    Get-ChildItem -LiteralPath $resolved -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $resolved | Out-Null
}

Copy-Item -Path (Join-Path $buildWeb '*') -Destination $resolved -Recurse -Force

Write-Host ''
Write-Host "Web 产物已复制到 $resolved"
Write-Host '本地直跑后端：重启或刷新即可访问 http://localhost:8000/'
Write-Host '容器化：在 docker/ 下运行 docker compose build backend（或 docker compose up -d --build backend）'
