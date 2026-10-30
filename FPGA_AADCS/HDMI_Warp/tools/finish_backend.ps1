param([Parameter(Mandatory=$true)][string]$CandidateRoot,[string]$PdsRoot='F:/PDS_2022.2-SP6.4')
$ErrorActionPreference='Stop'
$candidateRoot=(Resolve-Path -LiteralPath $CandidateRoot).Path
$projectRoot=Split-Path $PSScriptRoot -Parent
$backendExe=Join-Path $PdsRoot 'bin/pds_shell.exe'
$pythonExe=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
if(!(Test-Path -LiteralPath $pythonExe)){$pythonExe='python'}
$project=Join-Path $candidateRoot 'hdmi_warp.pds'
$mapDb=Join-Path $candidateRoot 'device_map/hdmi_warp_top_map.adf'
$pnrDir=Join-Path $candidateRoot 'place_route'
$pnrDb=(Join-Path $pnrDir 'hdmi_warp_top_pnr.adf').Replace('\','/')
if(!(Test-Path -LiteralPath $mapDb) -or (Test-Path -LiteralPath $pnrDb)){
 throw 'Requires a completed map in a fresh implementation directory.'
}
New-Item -ItemType Directory -Path $pnrDir -Force | Out-Null
Push-Location $pnrDir
try{
 & $backendExe -action place_route -fix_hold_violation '' -fix_hold_violation_iterations 100 -gplace_seed 4 -mode normal -project_file $project $mapDb *> (Join-Path $candidateRoot 'backend_pnr.log')
 if($LASTEXITCODE -ne 0){throw 'PNR failed'}
}finally{Pop-Location}
if(!(Test-Path -LiteralPath $pnrDb) -or (Select-String -LiteralPath (Join-Path $candidateRoot 'backend_pnr.log') -Pattern '^E:')){throw 'PNR incomplete or failed'}
$timingDir=Join-Path $candidateRoot 'report_timing'
New-Item -ItemType Directory -Path $timingDir -Force | Out-Null
Push-Location $timingDir
try{
 & $backendExe -action report_timing -project_file $project $pnrDb *> (Join-Path $candidateRoot 'backend_sta.log')
 if($LASTEXITCODE -ne 0){throw 'Independent STA failed'}
}finally{Pop-Location}
$report=Join-Path $timingDir 'hdmi_warp_top.rtr'
& $pythonExe (Join-Path $projectRoot 'tools/check_timing.py') $report --minimum 0.197 > (Join-Path $candidateRoot 'formal_timing_check.json')
$timingPassed=$LASTEXITCODE -eq 0
$exportTcl=Join-Path $candidateRoot 'export_actual.tcl'
$mapPath=$mapDb.Replace('\','/')
$pcfPath=(Join-Path $candidateRoot 'hdmi_warp.pcf').Replace('\','/')
$actualPath=(Join-Path $candidateRoot 'actual_placement.pcf').Replace('\','/')
@"
generate_constraint -db {$pnrDb} -devmap_db {$mapPath} -pcf {$pcfPath} -file {$actualPath}
exit
"@ | Set-Content -LiteralPath $exportTcl -Encoding utf8
& $backendExe -file $exportTcl -work_dir $candidateRoot -project_name export_actual *> (Join-Path $candidateRoot 'export_actual.log')
if($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $actualPath)){throw 'Actual placement export failed'}
if(!$timingPassed){throw 'Final STA failed +0.197ns; reports retained, no bitstream generated'}
$bitTcl=Join-Path $candidateRoot 'bit_from_pnr.tcl'
@"
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG484
gen_bit_stream -force_to_run -input_db_file {$pnrDb} -scbv {High Voltage}
"@ | Set-Content -LiteralPath $bitTcl -Encoding utf8
& $backendExe -file $bitTcl -work_dir $candidateRoot -project_name bit_from_pnr *> (Join-Path $candidateRoot 'bit_from_pnr.log')
$bit=Join-Path $candidateRoot 'generate_bitstream/hdmi_warp_top.sbit'
if($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $bit) -or (Select-String -LiteralPath (Join-Path $candidateRoot 'bit_from_pnr.log') -Pattern '^E:')){throw 'Bit generation failed'}
[ordered]@{
 created=(Get-Date -Format o); bit_sha256=(Get-FileHash -LiteralPath $bit).Hash
 map_sha256=(Get-FileHash -LiteralPath $mapDb).Hash; pcf_sha256=(Get-FileHash -LiteralPath $pcfPath).Hash
 minimum_setup_ns=0.197; seed=4; route_mode='normal'; board_programmed=$false
 warp_read_weight=2; sample_pipeline=1; capture_count_pipeline=1
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $candidateRoot 'release_manifest.json') -Encoding utf8
Write-Output "Formal timing and bit generation passed: $bit. Board has NOT been programmed."
