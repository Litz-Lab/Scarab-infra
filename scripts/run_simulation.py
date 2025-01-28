#!/usr/bin/python3

# 01/27/2025 | Surim Oh | run_simulation.py
# An entrypoint script that performs Scarab runs on Slurm clusters using docker containers or on local

import subprocess
import argparse
import os
from utilities import read_descriptor_from_json, verify_descriptor
import slurm_runner
import local_runner


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Runs scarab on local or a slurm network')

    # Add arguments
    parser.add_argument('-d','--descriptor_name', required=True, help='Experiment descriptor name. Usage: -d exp.json')
    parser.add_argument('-k','--kill', required=False, default=False, action=argparse.BooleanOptionalAction, help='Don\'t launch jobs from descriptor, kill running jobs as described in descriptor')
    parser.add_argument('-i','--info', required=False, default=False, action=argparse.BooleanOptionalAction, help='Get info about all nodes and if they have containers for slurm workloads')
    # parser.add_argument('-l','--launch', required=False, default=None, help='Launch a docker container on a node for the purpose of development/debugging. Use ? to pick a random node. Usage: -l bohr1')
    parser.add_argument('-dbg','--debug', required=False, type=int, default=2, help='1 for errors, 2 for warnings, 3 for info')
    parser.add_argument('-a','--arch_params', required=False, default=None, help='Path to a custom <architecture>.PARAMS file for scarab')
    parser.add_argument('-si','--scarab_infra', required=False, default=None, help='Path to scarab infra repo to launch new containers')

    # Parse the command-line arguments
    args = parser.parse_args()

    # Assign clear names to arguments
    descriptor_path = args.descriptor_name
    arch_params_file = args.arch_params
    dbg_lvl = args.debug
    infra_dir = args.scarab_infra

    if infra_dir == None:
        infra_dir = subprocess.check_output(["pwd"]).decode("utf-8").split("\n")[0]

    # Read descriptor json and extract important data
    descriptor_data = read_descriptor_from_json(descriptor_path, dbg_lvl)
    verify_descriptor(descriptor_data, infra_dir, dbg_lvl)

    workload_manager = descriptor_data["workload_manager"]

    if workload_manager == "manual":
        local_runner.run_simulation(args, descriptor_data, dbg_lvl)
    else:
        slurm_runner.run_simulation(args, descriptor_data, dbg_lvl)