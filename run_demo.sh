#!/bin/bash
# ==============================================================================
# PROJECT GODFATHER - AUTOMATED DEMO PIPELINE (LINUX/MAC)
# ==============================================================================

echo -e "\e[36m==================================================\e[0m"
echo -e "\e[36m  JARVIS CORP: PROJECT GODFATHER INITIALIZATION   \e[0m"
echo -e "\e[36m==================================================\e[0m"

echo -e "\n\e[33m[1/3] Checking Python Dependencies...\e[0m"
pip install -r requirements.txt > /dev/null

echo -e "\n\e[33m[2/3] Compiling Mixed-Signal Silicon Physics...\e[0m"
vlog src/analog_model/*.sv src/digital/*.sv src/*.sv tb/*.sv

if [ $? -ne 0 ]; then
    echo -e "\e[31mERROR: Verilog compilation failed. Ensure Questa/ModelSim is in your PATH.\e[0m"
    exit 1
fi

echo -e "\n\e[33mRunning Analog Simulation (1S1R Matrix)...\e[0m"
vsim -c tb_godfather_core -do "run -all; quit"

if [ ! -f "brain_telemetry.csv" ]; then
    echo -e "\e[31mERROR: Simulation failed to generate telemetry data.\e[0m"
    exit 1
fi

echo -e "\n\e[33m[3/3] Executing NeuroForge SDK (Visualizing STDP Learning)...\e[0m"
python3 sdk/run_neuroforge.py

echo -e "\n\e[36m==================================================\e[0m"
echo -e "\e[32mDEMO COMPLETE. Check the 'brain_renders' folder!\e[0m"
echo -e "\e[36m==================================================\e[0m"
