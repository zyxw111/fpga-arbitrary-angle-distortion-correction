param([ValidateSet('compile','synthesize','dev_map','pnr','report_timing','gen_bit_stream')][string]$Action='gen_bit_stream',[string]$PdsRoot='F:\PDS_2022.2-SP6.4')
$ErrorActionPreference='Stop'
$buildRoot=$PSScriptRoot
& (Join-Path $PdsRoot 'bin\pds_shell.exe') -project (Join-Path $buildRoot 'board_bars.pds') -work_dir $buildRoot -run $Action *> (Join-Path $buildRoot "$Action.log")
if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $buildRoot "$Action.log") -Pattern "^E:|Program Error Out|All Constraints NOT Met")){Get-Content -LiteralPath (Join-Path $buildRoot "$Action.log") -Tail 25;throw "BOARD DEMO $Action failed"}
Write-Output "PASS BOARD DEMO $Action; logs: $buildRoot"

if($Action -eq "gen_bit_stream"){ $r=Join-Path $buildRoot "report_timing/board_bars.rtr"; if(!(Test-Path $r) -or !(Select-String -LiteralPath $r -SimpleMatch "Design Summary : All Constraints Met.")){throw "Timing did not pass"} }
