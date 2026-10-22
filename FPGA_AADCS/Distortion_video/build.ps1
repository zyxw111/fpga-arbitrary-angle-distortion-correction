param([ValidateSet('compile','synthesize','dev_map','pnr','report_timing','gen_bit_stream')][string]$Action='gen_bit_stream',[string]$PdsRoot='F:\PDS_2022.2-SP6.4')
$ErrorActionPreference='Stop'
$buildRoot=Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
# PDS writes its state back into the project. Keep the portable GUI entry clean.
$template=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'board_video.pds') -Raw
# GUI saves populated flow state/output paths into the source PDS. Rebuild
# independently and keep every generated file inside this isolated directory.
$template=[regex]::Replace($template,'(\(_gci_state \(_integer )\d+(\)\))','${1}0${2}')
$template=[regex]::Replace($template,'(\(_(?:file|ip|ip_source_item) ")([^"]+)(")',{
 param($m)
 $relative=$m.Groups[2].Value
 $pathRoot=$PSScriptRoot
 if($relative -match '^(compile|synthesize|device_map|place_route|report_timing|report_power|generate_bitstream|generate_netlist|constraint_check)/'){$pathRoot=$buildRoot}
 $resolved=[IO.Path]::GetFullPath((Join-Path $pathRoot $relative)).Replace('\','/')
 # Mapping refreshes the PCF header; keep that write inside the build directory.
 if([IO.Path]::GetExtension($resolved) -in @('.fdc','.pcf')){
  $localConstraint=Join-Path $buildRoot ([IO.Path]::GetFileName($resolved))
  Copy-Item -LiteralPath $resolved -Destination $localConstraint -Force
  $resolved=$localConstraint.Replace('\','/')
 }
 $m.Groups[1].Value+$resolved+$m.Groups[3].Value
})
$project=Join-Path $buildRoot 'board_video.pds'
[IO.File]::WriteAllText($project,$template,[Text.UTF8Encoding]::new($false))
& (Join-Path $PdsRoot 'bin\pds_shell.exe') -project $project -work_dir $buildRoot -run $Action *> (Join-Path $buildRoot "$Action.log")
if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $buildRoot "$Action.log") -Pattern "^E:|Program Error Out|All Constraints NOT Met")){Get-Content -LiteralPath (Join-Path $buildRoot "$Action.log") -Tail 25;throw "BOARD DEMO $Action failed"}
Write-Output "PASS BOARD DEMO $Action; logs: $buildRoot"

if($Action -eq "gen_bit_stream"){ $r=Join-Path $buildRoot "report_timing/boardtop.rtr"; if(!(Test-Path $r) -or !(Select-String -LiteralPath $r -SimpleMatch "Design Summary : All Constraints Met.")){throw "Timing did not pass"} }
