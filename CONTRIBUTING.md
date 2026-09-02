# Contributing to Project GODFATHER

Thank you for your interest in contributing to the post-GPU era! Project GODFATHER is an ambitious open-source initiative to revolutionize Artificial Intelligence Hardware via Analog Neuromorphic computing.

## Code of Conduct
We expect all contributors to adhere to standard professional open-source conduct. Be respectful, constructive, and highly rigorous in your mathematics and logic.

## How to Contribute
1. **Fork the Repository:** Create your own fork and branch off `master`.
2. **Setup your Environment:** Run `pip install -e .` to install the NeuroForge SDK.
3. **Run Tests:** Ensure you run `pytest tests/ -v` and maintain the 100% pass rate.
4. **Submit a Pull Request (PR):** Document your changes meticulously. 

### Architecture Guidelines
- **Hardware (SystemVerilog):** All hardware additions must go in `src/`. Do not break the asynchronous NoC boundaries.
- **Software (Python):** All compiler additions must go in `sdk/neuroforge/`. Ensure your code handles analog physical limits (Quantization, RC Delay, Crossbar shattering) perfectly.

## Reporting Bugs
If you find a discrepancy in the PPA Profiler or the Digital Twin physics engine, please open an Issue with the exact PyTorch architecture that caused the mathematical fault.
