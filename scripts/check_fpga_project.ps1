param([string]$PdsRoot = 'F:\PDS_2022.2-SP6.4')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fpgaRoot = Join-Path $repoRoot 'FPGA_AADCS'
$checkRoot = Join-Path $repoRoot '.cache\gui-pds-validation'
$shell = Join-Path $PdsRoot 'bin\pds_shell.exe'
if (-not (Test-Path -LiteralPath $shell)) { throw "PDS shell not found: $shell" }
New-Item -ItemType Directory -Path $checkRoot -Force | Out-Null
# Validate the GUI input with PDS itself. An isolated copy prevents the shell
# from writing transient compile status/output paths back to the tracked file.
$content = Get-Content -LiteralPath (Join-Path $fpgaRoot 'FPGA_AADCS.pds') -Raw
$pattern = '(\((?:_file|_ip|_ip_source_item)\s+")([^"]+)(")'
$absoluteContent = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{
    param($match)
    $path = $match.Groups[2].Value
    if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $fpgaRoot $path }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing project input: $path" }
    return $match.Groups[1].Value + $path.Replace('\', '/') + $match.Groups[3].Value
})
$checkProject = Join-Path $checkRoot 'FPGA_AADCS.pds'
[System.IO.File]::WriteAllText($checkProject, $absoluteContent, [System.Text.UTF8Encoding]::new($false))
$log = Join-Path $checkRoot 'console.log'
& $shell -project $checkProject -work_dir $checkRoot -run compile *> $log
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $log -Tail 25
    throw "GUI project validation failed; see $log"
}
Write-Output 'PASS GUI PDS: project parsed and RTL compiled by PDS.'
