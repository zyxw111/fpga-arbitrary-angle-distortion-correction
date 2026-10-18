param([ValidateSet('compile','synthesize','dev_map','pnr','report_timing','gen_bit_stream')][string]$Action='gen_bit_stream',[string]$PdsRoot='F:\PDS_2022.2-SP6.4')
$ErrorActionPreference='Stop'
$buildRoot=$PSScriptRoot
& (Join-Path $PdsRoot 'bin\pds_shell.exe') -project (Join-Path $buildRoot 'ddr_bist.pds') -work_dir $buildRoot -run $Action *> (Join-Path $buildRoot "$Action.log")
if($LASTEXITCODE -ne 0){Get-Content -LiteralPath (Join-Path $buildRoot "$Action.log") -Tail 25;throw "DDR BIST $Action failed"}
Write-Output "PASS DDR BIST $Action; logs: $buildRoot"
