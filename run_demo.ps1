# ==============================================================================
# PROJECT GODFATHER - AUTOMATED DEMO PIPELINE
# ==============================================================================
# This script is idiot-proof. It compiles the architecture, runs the analog
# simulation, and renders the Python neuroplasticity heatmaps.

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  JARVIS CORP: PROJECT GODFATHER INITIALIZATION   " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Check for Python dependencies
Write-Host "`n[1/3] Checking Python Dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt | Out-Null

# 2. Compile and Simulate via Questa/ModelSim
Write-Host "`n[2/3] Compiling Mixed-Signal Silicon Physics..." -ForegroundColor Yellow
vlog src/analog_model/*.sv src/digital/*.sv src/*.sv tb/*.sv

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Verilog compilation failed. Ensure Questa/ModelSim is in your PATH." -ForegroundColor Red
    exit
}

Write-Host "`nRunning Analog Simulation (1S1R Matrix)..." -ForegroundColor Yellow
# Note: If you encounter license errors, set your license server here:
# $env:SALT_LICENSE_SERVER="C:\altera_lite\LR-XXXXXX_License.dat"
vsim -c tb_godfather_core -do "run -all; quit"

if (-Not (Test-Path "brain_telemetry.csv")) {
    Write-Host "ERROR: Simulation failed to generate telemetry data." -ForegroundColor Red
    exit
}

# 3. Render the output
Write-Host "`n[3/3] Executing NeuroForge SDK (Visualizing STDP Learning)..." -ForegroundColor Yellow
python sdk/run_neuroforge.py

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "DEMO COMPLETE. Check the 'brain_renders' folder!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
