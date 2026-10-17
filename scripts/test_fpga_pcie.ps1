param([string]$IcarusBin = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $IcarusBin) {
    $localBin = Join-Path $repoRoot '.cache\tools\iverilog\bin'
    if (Test-Path -LiteralPath (Join-Path $localBin 'iverilog.exe')) { $IcarusBin = $localBin }
}
if ($IcarusBin) {
    $iverilog = Join-Path $IcarusBin 'iverilog.exe'
    $vvp = Join-Path $IcarusBin 'vvp.exe'
    $env:PATH = $IcarusBin + ';' + $env:PATH
} else {
    $iverilog = (Get-Command iverilog -ErrorAction Stop).Source
    $vvp = (Get-Command vvp -ErrorAction Stop).Source
}
Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Path 'FPGA_AADCS\sim\results' -Force | Out-Null
    $dmaFiles = Get-ChildItem -LiteralPath 'FPGA_AADCS\rtl\pcie_dma' -Recurse -Filter '*.v' |
        Where-Object Name -NotMatch '_init_param|_Reset_Value' | ForEach-Object FullName
    foreach ($bench in @('tb_pcie_test_source', 'tb_pcie_registers', 'tb_pcie_mwr', 'tb_pcie_reset', 'tb_pcie_dma_host')) {
        $benchFiles = $dmaFiles
        if ($bench -eq 'tb_pcie_dma_host') {
            $benchFiles = @($dmaFiles | Where-Object { $_ -notmatch 'ips2l_pcie_dma_ram[\\/]' }) +
                @('FPGA_AADCS/sim/pcie_dma_ram_model.v')
        }
        $result = 'FPGA_AADCS/sim/results/' + $bench + '.vvp'
        & $iverilog -g2012 -s $bench -I FPGA_AADCS/rtl/pcie_dma/ips2l_pcie_dma_ram/rtl `
            -o $result ('FPGA_AADCS/sim/' + $bench + '.v') FPGA_AADCS/rtl/pcie_test_source.v `
            FPGA_AADCS/rtl/pcie_reset_control.v @benchFiles
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $bench ($LASTEXITCODE)" }
        & $vvp $result
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $bench ($LASTEXITCODE)" }
    }
} finally { Pop-Location }
