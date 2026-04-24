param(
    [string]$MinecraftDir = "E:/Minecraft/.minecraft",
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"

Write-Host "[1/3] Building shaderpack..."
& $PythonExe "build.py"
if ($LASTEXITCODE -ne 0) {
    throw "build.py failed with exit code $LASTEXITCODE"
}

$logPath = Join-Path $MinecraftDir "logs/latest.log"
if (-not (Test-Path $logPath)) {
    throw "Cannot find log file: $logPath"
}

Write-Host "[2/3] Build done. Watching Iris log output..."
Write-Host "Press Ctrl+C to stop."

Get-Content $logPath -Wait -Tail 0 |
    Where-Object {
        $_ -match "iris|shader|ShaderCompileException|ERROR|Exception"
    } |
    ForEach-Object {
        Write-Host $_
    }
