param([string]$BuildDir='build/live60-release',[string]$PdsRoot='F:/PDS_2022.2-SP6.4',[switch]$MirrorBorder)
$ErrorActionPreference='Stop'
$candidateRoot=Join-Path $PSScriptRoot $BuildDir
if(Test-Path -LiteralPath (Join-Path $candidateRoot 'device_map/hdmi_warp_top_map.adf')){
 throw 'Choose a fresh BuildDir; preserve previous maps, timing reports and bitstreams.'
}
# Explicit release preset; build.ps1 retains all legacy A/B switches.
& (Join-Path $PSScriptRoot 'build.ps1') -Action dev_map -BuildDir $BuildDir -PdsRoot $PdsRoot -Seed 4 -RouteMode normal -RtlSnapshot -HostReads 8 -OutputBanks 2 -CaptureFifoBits 13 -CaptureWriteBanks 2 -WarpReadWeight 2 -SamplePipeline 1 -CaptureCountPipeline 1 -MirrorBorder:$MirrorBorder
if(!$?){throw 'Release mapping failed'}
# Mapping rewrites PCF. Apply physical hints only after it has completed.
Add-Content -LiteralPath (Join-Path $candidateRoot 'hdmi_warp.pcf') -Value (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'constraints/three_axis_r6.pcf') -Raw)
& (Join-Path $PSScriptRoot 'tools/finish_backend.ps1') -CandidateRoot $candidateRoot -PdsRoot $PdsRoot
