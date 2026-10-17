param([string]$PdsRoot = 'F:\PDS_2022.2-SP6.4', [string]$IcarusBin = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $IcarusBin) { $IcarusBin = Join-Path $repoRoot '.cache\tools\iverilog\bin' }
$env:PATH = $IcarusBin + ';' + $env:PATH
$simlib = Join-Path $PdsRoot 'arch\vendor\pango\verilog\simulation'
Push-Location $repoRoot
try {
    foreach ($target in @('pcie_test_source','pcie_gate_fixture')) {
        $env:AADCS_GATE_TOP = $target
        $output = Join-Path $repoRoot ('FPGA_AADCS\build\gate\' + $target)
        New-Item -ItemType Directory -Path $output -Force | Out-Null
        & (Join-Path $PdsRoot 'bin\pds_shell.exe') -file (Join-Path $repoRoot 'FPGA_AADCS\sim\build_gate.tcl') -work_dir $output *> (Join-Path $output 'console.log')
        if ($LASTEXITCODE -ne 0) { throw "Gate synthesis failed: $output" }
        $bench = if ($target -eq 'pcie_test_source') { 'tb_pcie_test_source' } else { 'tb_pcie_reset' }
        $netlist = Join-Path $output ('synthesize\' + $target + '_syn.vm')
        $result = Join-Path $output 'test.vvp'
        & (Join-Path $IcarusBin 'iverilog.exe') -g2012 -DGATE_SIM -s $bench -y $simlib `
            -o $result ('FPGA_AADCS/sim/' + $bench + '.v') $netlist
        if ($LASTEXITCODE -ne 0) { throw "Gate compilation failed: $target" }
        & (Join-Path $IcarusBin 'vvp.exe') $result
        if ($LASTEXITCODE -ne 0) { throw "Gate simulation failed: $target" }
    }
} finally {
    Remove-Item Env:AADCS_GATE_TOP -ErrorAction SilentlyContinue
    Pop-Location
}
