param([string]$PdsRoot='F:\PDS_2022.2-SP6.4',[switch]$Debug,[string]$BuildDir='build',[ValidateRange(0,100)][double]$MinimumSetupNs=0.197)
$ErrorActionPreference='Stop'
$buildRoot=Join-Path $PSScriptRoot $BuildDir
if($Debug){$buildRoot=Join-Path $buildRoot 'debug'}
$timing=Join-Path $buildRoot 'report_timing/hdmi_warp_top.rtr'
$bit=Join-Path $buildRoot 'generate_bitstream/hdmi_warp_top.sbit'
if(!(Test-Path -LiteralPath $bit) -or !(Test-Path -LiteralPath $timing) -or
   !(Select-String -LiteralPath $timing -SimpleMatch 'Design Summary : All Constraints Met.')){
 throw 'Build this HDMI project successfully, including timing, before programming.'
}
$programPython=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
if(!(Test-Path -LiteralPath $programPython)){$programPython='python'}
& $programPython (Join-Path $PSScriptRoot 'tools/check_timing.py') $timing --minimum $MinimumSetupNs
if($LASTEXITCODE -ne 0){throw "Final timing report fails the required +$MinimumSetupNs ns setup margin; not programming."}
if(!(Get-NetTCPConnection -LocalPort 65420 -State Listen -ErrorAction SilentlyContinue)){
 $programJtagServer=Start-Process -FilePath (Join-Path $PdsRoot 'bin/cdt_js.exe') -WorkingDirectory $buildRoot -WindowStyle Hidden -PassThru
 $programServerDeadline=[DateTime]::UtcNow.AddSeconds(30)
 while(!(Get-NetTCPConnection -LocalPort 65420 -State Listen -ErrorAction SilentlyContinue)){
  $programJtagServer.Refresh()
  if($programJtagServer.HasExited){throw 'JTAG Server exited before listening.'}
  if([DateTime]::UtcNow -ge $programServerDeadline){throw 'JTAG Server did not become ready within 30 seconds.'}
  Start-Sleep -Milliseconds 500
 }
}
$previousBit=$env:AADCS_BITSTREAM
try{
 $env:AADCS_BITSTREAM=$bit.Replace('\','/')
 & (Join-Path $PdsRoot 'bin/cdt_cfg_shell.exe') -file (Join-Path $PSScriptRoot 'tools/program_hdmi.tcl') *> (Join-Path $buildRoot 'program.log')
 $log=Get-Content -LiteralPath (Join-Path $buildRoot 'program.log') -Raw
 if($LASTEXITCODE -ne 0 -or $log -match '(?m)^E:|PROGRAM_RESULT=1'){throw "HDMI programming failed; see $buildRoot/program.log"}
 Write-Output "HDMI SRAM programming finished: $bit; verify DONE/CRC in $buildRoot/program.log"
}finally{$env:AADCS_BITSTREAM=$previousBit}
