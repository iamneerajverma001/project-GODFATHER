import argparse
import sys
import os

def print_banner():
    print(r"""
============================================================
   _   _                     _____                       
  | \ | |                   |  ___|                      
  |  \| | ___ _   _ _ __ ___| |_ ___  _ __ __ _  ___     
  | . ` |/ _ \ | | | '__/ _ \  _/ _ \| '__/ _` |/ _ \    
  | |\  |  __/ |_| | | | (_) | || (_) | | | (_| |  __/    
  \_| \_/\___|\__,_|_|  \___/\_| \___/|_|  \__, |\___|    
                                            __/ |        
                                           |___/         
  Project GODFATHER - Hardware-Software Co-Design SDK v1.0
============================================================
    """)

def handle_compile(args):
    print(f"NeuroForge CLI: Compiling PyTorch model from {args.model_script}")
    # In a real environment, this would dynamically import the user's script
    # and intercept the model. For now, we will run our test script.
    import subprocess
    subprocess.run([sys.executable, "sdk/run_neuroforge.py"])

def handle_profile(args):
    print(f"NeuroForge CLI: Profiling PPA metrics for NoC routing table at {args.routing_table}")
    from neuroforge.profiler import NeuroForgeProfiler
    profiler = NeuroForgeProfiler(routing_table_path=args.routing_table)
    profiler.generate_ppa_report()

def handle_board(args):
    from neuroforge.board import launch_dashboard
    launch_dashboard(port=args.port)

def handle_swarm(args):
    from neuroforge.hub import launch_swarm_hub
    launch_swarm_hub(port=args.port)

def main():
    parser = argparse.ArgumentParser(description="NeuroForge SDK Command Line Interface")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Command: compile
    parser_compile = subparsers.add_parser("compile", help="Compile a PyTorch model into physical .mem Crossbar weights and NoC routing tables.")
    parser_compile.add_argument("model_script", type=str, help="Path to the Python script containing the NeuroGraph model.")
    parser_compile.add_argument("--out", type=str, default="sdk/build", help="Output directory for hardware binaries.")

    # Command: profile
    parser_profile = subparsers.add_parser("profile", help="Generate a Power, Performance, and Area (PPA) report for a compiled model.")
    parser_profile.add_argument("--routing-table", type=str, default="sdk/build/noc_routing.json", help="Path to the compiled noc_routing.json")

    # Command: board
    parser_board = subparsers.add_parser("board", help="Launch NeuroBoard to visualize the physical NoC routing and PPA metrics.")
    parser_board.add_argument("--port", type=int, default=8080, help="Port to run the dashboard on.")

    # Command: swarm
    parser_swarm = subparsers.add_parser("swarm", help="Launch the global SwarmHub registry to sync encrypted STDP telemetry across edge devices.")
    parser_swarm.add_argument("--port", type=int, default=9999, help="Port to run the swarm registry on.")

    args = parser.parse_args()

    if args.command is None:
        print_banner()
        parser.print_help()
        sys.exit(1)

    print_banner()
    if args.command == "compile":
        handle_compile(args)
    elif args.command == "profile":
        handle_profile(args)
    elif args.command == "board":
        handle_board(args)
    elif args.command == "swarm":
        handle_swarm(args)

if __name__ == "__main__":
    main()
