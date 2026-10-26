param([string]$PdsRoot='F:\PDS_2022.2-SP6.4',[switch]$Debug)
$ErrorActionPreference='Stop'
$buildRoot=Join-Path $PSScriptRoot 'build'
if($Debug){$buildRoot=Join-Path $buildRoot 'debug'}
$timing=Join-Path $buildRoot 'report_timing/hdmi_warp_top.rtr'
$bit=Join-Path $buildRoot 'generate_bitstream/hdmi_warp_top.sbit'
if(!(Test-Path -LiteralPath $bit) -or !(Test-Path -LiteralPath $timing) -or
   !(Select-String -LiteralPath $timing -SimpleMatch 'Design Summary : All Constraints Met.')){
 throw 'Build this HDMI project successfully, including timing, before programming.'
}
if(!(Get-NetTCPConnection -LocalPort 65420 -State Listen -ErrorAction SilentlyContinue)){
 Start-Process -FilePath (Join-Path $PdsRoot 'bin/cdt_js.exe') -WorkingDirectory $buildRoot -WindowStyle Hidden
 Start-Sleep -Seconds 2
}
$previousBit=$env:AADCS_BITSTREAM
try{
 $env:AADCS_BITSTREAM=$bit.Replace('\','/')
 & (Join-Path $PdsRoot 'bin/cdt_cfg_shell.exe') -file (Join-Path $PSScriptRoot 'tools/program_hdmi.tcl') *> (Join-Path $buildRoot 'program.log')
 $log=Get-Content -LiteralPath (Join-Path $buildRoot 'program.log') -Raw
 if($LASTEXITCODE -ne 0 -or $log -match '(?m)^E:|PROGRAM_RESULT=1'){throw "HDMI programming failed; see $buildRoot/program.log"}
 Write-Output "HDMI SRAM programming finished: $bit; verify DONE/CRC in $buildRoot/program.log"
}finally{$env:AADCS_BITSTREAM=$previousBit}
