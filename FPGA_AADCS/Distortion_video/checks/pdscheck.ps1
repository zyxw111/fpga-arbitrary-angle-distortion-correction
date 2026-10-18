param([string[]]$Tops=@('store','fetch','bridge','video'),[string]$Action='synthesize',[string]$PdsRoot='F:\PDS_2022.2-SP6.4')
$ErrorActionPreference='Stop'
$videoRoot=Split-Path -Parent $PSScriptRoot
$template=Get-Content -LiteralPath (Join-Path $videoRoot 'Distortion_re.pds') -Raw
foreach($top in $Tops){
 $checkRoot=Join-Path $videoRoot "checks\upgrade_$top"
 New-Item -ItemType Directory -Path $checkRoot -Force | Out-Null
 $entries=(Get-ChildItem -LiteralPath (Join-Path $videoRoot 'source\rtl') -Filter '*.v' | ForEach-Object {
  $path=$_.FullName.Replace('\','/');$select=if($_.BaseName -eq $top){" + `"$top`""}else{''}
  "                (_file `"$path`"$select`r`n                    (_format verilog)`r`n                    (_timespec `"2026-10-17T23:30:00`")`r`n                )`r`n"
 }) -join ''
 $block="        (_widget wgt_my_design_src`r`n            (_input`r`n$entries            )`r`n        )`r`n"
 $text=[regex]::Replace($template,'(?s)        \(_widget wgt_my_design_src.*?(?=        \(_widget wgt_my_ips_src)',$block)
 $text=[regex]::Replace($text,'(?s)        \(_widget wgt_import_logic_con_file.*?(?=        \(_widget wgt_edit_user_cons)',"        (_widget wgt_import_logic_con_file)`r`n")
 $text=$text.Replace('"vtop"',"`"$top`"")
 $project=Join-Path $checkRoot "$top.pds"
 [IO.File]::WriteAllText($project,$text,[Text.UTF8Encoding]::new($false))
 $log=Join-Path $checkRoot "$Action.log"
 & (Join-Path $PdsRoot 'bin\pds_shell.exe') -project $project -work_dir $checkRoot -run $Action *> $log
 if($LASTEXITCODE -ne 0){Get-Content -LiteralPath $log -Tail 25;throw "PDS $top $Action failed"}
 Write-Output "PASS PDS $Action $top"
}
