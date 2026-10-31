param([ValidateSet('compile','synthesize','dev_map','pnr','report_timing','gen_bit_stream')][string]$Action='gen_bit_stream',[string]$PdsRoot='F:\PDS_2022.2-SP6.4',[string]$PythonExe='',[switch]$Debug,[int]$Seed=4,[string]$BuildDir='build',[switch]$PerfDisable,[switch]$WarpSerial,[ValidateRange(1,8)][int]$OutputBanks=2,[ValidateSet(1,2,4,8,16)][int]$HostReads=8,[switch]$RtlSnapshot,[switch]$LegacyWarp,[ValidateSet('fast','normal','performance')][string]$RouteMode='performance',[ValidateRange(3,14)][int]$CaptureFifoBits=13,[ValidateSet(1,2)][int]$CaptureWriteBanks=2,[ValidateRange(1,4)][int]$WarpReadWeight=1,[ValidateSet(0,1)][int]$SamplePipeline=0,[ValidateSet(0,1)][int]$CaptureCountPipeline=0,[switch]$MirrorBorder)
$ErrorActionPreference='Stop'
if($MirrorBorder -and ($LegacyWarp -or $WarpSerial)){throw 'MirrorBorder requires the fast warp engine'}
if(!$PythonExe){
 $bundled=Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
 $PythonExe=if(Test-Path -LiteralPath $bundled){$bundled}else{'python'}
}
& $PythonExe (Join-Path $PSScriptRoot 'tools\configure.py')
if($LASTEXITCODE -ne 0){throw 'Invalid HDMI warp configuration'}
$buildRoot=Join-Path $PSScriptRoot $BuildDir
if($Debug){$buildRoot=Join-Path $buildRoot 'debug'}
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
# PDS writes its state back into the project. Keep the portable GUI entry clean.
$template=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'hdmi_warp.pds') -Raw
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
if($PerfDisable -or $WarpSerial -or $OutputBanks -ne 2 -or $HostReads -ne 8 -or $LegacyWarp -or $CaptureFifoBits -ne 13 -or $CaptureWriteBanks -ne 2 -or $WarpReadWeight -ne 1 -or $SamplePipeline -ne 0 -or $CaptureCountPipeline -ne 0 -or $MirrorBorder){
 $topPath=(Join-Path $PSScriptRoot 'source/rtl/hdmi_warp_top.v').Replace('\','/')
 $localTop=(Join-Path $buildRoot 'hdmi_warp_top_configured.v').Replace('\','/')
 $topText=Get-Content -LiteralPath $topPath -Raw
 if($MirrorBorder){$topText=$topText.Replace('WARP_BORDER_MIRROR=0','WARP_BORDER_MIRROR=1')}
 if($PerfDisable){$topText=$topText.Replace('PERF_ENABLE=1','PERF_ENABLE=0')}
 if($WarpSerial){$topText=$topText.Replace('WARP_OVERLAP_WRITE=1','WARP_OVERLAP_WRITE=0')}
 if($LegacyWarp -or $WarpSerial){$topText=$topText.Replace('WARP_FAST=1','WARP_FAST=0')}
 if($OutputBanks -ne 2){$topText=$topText.Replace('WARP_OUTPUT_BANKS=2',"WARP_OUTPUT_BANKS=$OutputBanks")}
 if($HostReads -ne 8){$topText=$topText.Replace('HOST_READ_OUTSTANDING=8',"HOST_READ_OUTSTANDING=$HostReads")}
 if($CaptureFifoBits -ne 13){$topText=$topText.Replace('CAPTURE_FIFO_BITS=13',"CAPTURE_FIFO_BITS=$CaptureFifoBits")}
 if($CaptureWriteBanks -ne 2){$topText=$topText.Replace('CAPTURE_WRITE_BANKS=2',"CAPTURE_WRITE_BANKS=$CaptureWriteBanks")}
 if($WarpReadWeight -ne 1){$topText=$topText.Replace('WARP_READ_WEIGHT=1',"WARP_READ_WEIGHT=$WarpReadWeight")}
 if($SamplePipeline -ne 0){$topText=$topText.Replace('WARP_SAMPLE_PIPELINE=0',"WARP_SAMPLE_PIPELINE=$SamplePipeline")}
 if($CaptureCountPipeline -ne 0){$topText=$topText.Replace('CAPTURE_COUNT_PIPELINE=0',"CAPTURE_COUNT_PIPELINE=$CaptureCountPipeline")}
 [IO.File]::WriteAllText($localTop,$topText,[Text.UTF8Encoding]::new($false))
 $template=$template.Replace($topPath,$localTop)
}
if($RtlSnapshot){
 # PDS reads this immutable copy throughout its long build. Later edits to the
 # checkout cannot change the inputs of an already-running implementation.
 $snapshotRoot=Join-Path $buildRoot 'rtl_source'
 New-Item -ItemType Directory -Path $snapshotRoot -Force | Out-Null
 Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'source/rtl') -Filter '*.v' | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $snapshotRoot $_.Name) -Force
 }
 $template=$template.Replace(((Join-Path $PSScriptRoot 'source/rtl').Replace('\','/')+'/'),($snapshotRoot.Replace('\','/')+'/'))
 # Parameter overrides select this file instead of the default top. Include
 # that actual input in the immutable snapshot and its hash list as well.
 if($localTop -and $template.Contains($localTop)){
  $snapshotTop=Join-Path $snapshotRoot 'hdmi_warp_top_configured.v'
  Copy-Item -LiteralPath $localTop -Destination $snapshotTop -Force
  $template=$template.Replace($localTop,$snapshotTop.Replace('\','/'))
 }
 Get-ChildItem -LiteralPath $snapshotRoot -Filter '*.v' | Get-FileHash -Algorithm SHA256 | Select-Object Path,Hash | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $buildRoot 'rtl_source_sha256.json') -Encoding utf8
}
if($Debug){
 $ficPath=(Join-Path $buildRoot 'hdmi.fic').Replace('\','/')
 $netlist=(Join-Path $buildRoot 'synthesize/hdmi_warp_top_syn.adf').Replace('\','/')
 $ficText=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'debug/hdmi.fic.in') -Raw).Replace('@SYNTH_NETLIST@',$netlist)
 [IO.File]::WriteAllText($ficPath,$ficText,[Text.UTF8Encoding]::new($false))
 $widget="(_widget wgt_my_fic_src (_input (_file `"$ficPath`" (_format text) (_timespec `"2026-10-23T00:00:00`"))))"
 $template=[regex]::Replace($template,'\(_widget wgt_my_fic_src\s*\)',[Text.RegularExpressions.MatchEvaluator]{param($m) $widget})
}
$options="(_option gplace_seed (_integer $Seed)) (_option mode (_string `"$RouteMode`")) (_option fix_hold_violation (_switch ON)) (_option fix_hold_violation_iterations (_integer 100)) (_option fix_hold_violation_threshold (_integer 0))"
$template=$template.Replace('(_option mode (_string "performance"))','').Replace('(_option gplace_seed (_integer 4))','')
$template=$template.Replace('(_command cmd_pnr',"(_command cmd_pnr $options")
$project=Join-Path $buildRoot 'hdmi_warp.pds'
[IO.File]::WriteAllText($project,$template,[Text.UTF8Encoding]::new($false))
& (Join-Path $PdsRoot 'bin\pds_shell.exe') -project $project -work_dir $buildRoot -run $Action *> (Join-Path $buildRoot "$Action.log")
if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $buildRoot "$Action.log") -Pattern "^E:|Program Error Out|All Constraints NOT Met")){Get-Content -LiteralPath (Join-Path $buildRoot "$Action.log") -Tail 25;throw "HDMI WARP $Action failed"}
$compileLog=Join-Path $buildRoot 'compile/run.log'
if((Test-Path -LiteralPath $compileLog) -and (Select-String -LiteralPath $compileLog -Pattern 'Width mismatch between port page_completed|Net perf_enabled[.].*driver')){
 throw 'Performance tap binding failed (implicit or width-mismatched net); do not program this build.'
}
if($Action -eq 'gen_bit_stream'){
 $r=Join-Path $buildRoot 'report_timing/hdmi_warp_top.rtr'
 if(!(Test-Path -LiteralPath $r)){throw 'Missing final timing report'}
 & $PythonExe (Join-Path $PSScriptRoot 'tools/check_timing.py') $r
 if($LASTEXITCODE -ne 0){throw 'Timing or agreed setup margin did not pass'}
}
Write-Output "PASS HDMI WARP $Action; logs: $buildRoot"
