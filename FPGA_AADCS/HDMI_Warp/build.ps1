param([ValidateSet('compile','synthesize','dev_map','pnr','report_timing','gen_bit_stream')][string]$Action='gen_bit_stream',[string]$PdsRoot='F:\PDS_2022.2-SP6.4',[string]$PythonExe='',[switch]$Debug,[int]$Seed=2)
$ErrorActionPreference='Stop'
if(!$PythonExe){
 $bundled=Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
 $PythonExe=if(Test-Path -LiteralPath $bundled){$bundled}else{'python'}
}
& $PythonExe (Join-Path $PSScriptRoot 'tools\configure.py')
if($LASTEXITCODE -ne 0){throw 'Invalid HDMI warp configuration'}
$buildRoot=Join-Path $PSScriptRoot 'build'
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
if($Debug){
 $ficPath=(Join-Path $buildRoot 'hdmi.fic').Replace('\','/')
 $netlist=(Join-Path $buildRoot 'synthesize/hdmi_warp_top_syn.adf').Replace('\','/')
 $ficText=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'debug/hdmi.fic.in') -Raw).Replace('@SYNTH_NETLIST@',$netlist)
 [IO.File]::WriteAllText($ficPath,$ficText,[Text.UTF8Encoding]::new($false))
 $widget="(_widget wgt_my_fic_src (_input (_file `"$ficPath`" (_format text) (_timespec `"2026-10-23T00:00:00`"))))"
 $template=[regex]::Replace($template,'\(_widget wgt_my_fic_src\s*\)',[Text.RegularExpressions.MatchEvaluator]{param($m) $widget})
}
$options="(_option gplace_seed (_integer $Seed)) (_option fix_hold_violation (_switch ON)) (_option fix_hold_violation_iterations (_integer 100)) (_option fix_hold_violation_threshold (_integer 0))"
$template=$template.Replace('(_command cmd_pnr',"(_command cmd_pnr $options")
$project=Join-Path $buildRoot 'hdmi_warp.pds'
[IO.File]::WriteAllText($project,$template,[Text.UTF8Encoding]::new($false))
& (Join-Path $PdsRoot 'bin\pds_shell.exe') -project $project -work_dir $buildRoot -run $Action *> (Join-Path $buildRoot "$Action.log")
if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $buildRoot "$Action.log") -Pattern "^E:|Program Error Out|All Constraints NOT Met")){Get-Content -LiteralPath (Join-Path $buildRoot "$Action.log") -Tail 25;throw "HDMI WARP $Action failed"}
if($Action -eq "gen_bit_stream"){ $r=Join-Path $buildRoot "report_timing/hdmi_warp_top.rtr"; if(!(Test-Path $r) -or !(Select-String -LiteralPath $r -SimpleMatch "Design Summary : All Constraints Met.")){throw "Timing did not pass"} }
Write-Output "PASS HDMI WARP $Action; logs: $buildRoot"
