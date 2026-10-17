param([string]$PdsRoot = 'F:\PDS_2022.2-SP6.4', [switch]$DebugCore)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fpgaRoot = Join-Path $repoRoot 'FPGA_AADCS'
$buildRoot = Join-Path $fpgaRoot 'build'
if ($DebugCore) { $buildRoot = Join-Path $buildRoot 'debug' }
$shell = Join-Path $PdsRoot 'bin\pds_shell.exe'
if (-not (Test-Path -LiteralPath $shell)) { throw "PDS shell not found: $shell" }
& (Join-Path $PSScriptRoot 'check_fpga_project.ps1') -PdsRoot $PdsRoot
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$log = Join-Path $buildRoot 'console.log'
try {
    $env:AADCS_DEBUG = if ($DebugCore) { '1' } else { '0' }
    & $shell -file (Join-Path $fpgaRoot 'project\build.tcl') -work_dir $buildRoot *> $log
    $buildExitCode = $LASTEXITCODE
} finally { Remove-Item Env:AADCS_DEBUG -ErrorAction SilentlyContinue }
if ($buildExitCode -ne 0) {
    Get-Content -LiteralPath $log -Tail 30
    throw "PDS build failed; see $log"
}
Get-Content -LiteralPath $log -Tail 12
Write-Output "Build output: $buildRoot"
