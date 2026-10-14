param([string]$PdsRoot = 'F:\PDS_2022.2-SP6.4')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fpgaRoot = Join-Path $repoRoot 'FPGA_AADCS'
$buildRoot = Join-Path $fpgaRoot 'build'
$shell = Join-Path $PdsRoot 'bin\pds_shell.exe'
if (-not (Test-Path -LiteralPath $shell)) { throw "PDS shell not found: $shell" }
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$log = Join-Path $buildRoot 'console.log'
& $shell -file (Join-Path $fpgaRoot 'project\build.tcl') -work_dir $buildRoot *> $log
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $log -Tail 30
    throw "PDS build failed; see $log"
}
Get-Content -LiteralPath $log -Tail 12
Write-Output "Build output: $buildRoot"
