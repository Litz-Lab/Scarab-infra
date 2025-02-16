#!/usr/bin/python3

# 02/13/2025 | Surim Oh | run_db.py

import argparse
import subprocess
from utilities import (
        err,
        info,
        read_descriptor_from_json,
        validate_simulation,
        get_image_name
        )

def list_workloads(workloads_data, dbg_lvl = 2):
    print(f"Workload    <\033[92mSimulation mode\033[0m : \033[31mDocker image name to build\033[0m>")
    print("----------------------------------------------------------")
    workloads = workloads_data.keys()
    for workload in workloads:
        print(f"{workload}")
        modes = workloads_data[workload]["simulation"].keys()
        for mode in modes:
            image_name = workloads_data[workload]["simulation"][mode]["image_name"]
            print(f"            <\033[92m{mode}\033[0m : \033[31m{image_name}\033[0m>")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Query workload database')

    # Add arguments
    parser.add_argument('-wdb','--workload_db', required=True, help='Workload database descriptor name. Usage: -d ./workloads/workloads_db.json')
    parser.add_argument('-sdb','--suite_db', required=True, help='Benchmark suite database descriptor name. Usage: -d ./workloads/suite_db.json')
    parser.add_argument('-l','--list', required=False, default=False, action=argparse.BooleanOptionalAction, help='List all the workloads and their available simulation information')
    parser.add_argument('-val','--validate', required=False, default=None, help='Experiment descriptor name to validate. Usage: --validate ./json/exp.json')
    parser.add_argument('-g','--group', required=False, default=None, help='Experiment descriptor name to get a group name of the first simulation. Usage: --group ./json/exp.json')
    parser.add_argument('-dbg','--debug', required=False, type=int, default=2, help='1 for errors, 2 for warnings, 3 for info')
    parser.add_argument('-si','--scarab_infra', required=False, default=None, help='Path to scarab infra repo to launch new containers')

    # Parse the command-line arguments
    args = parser.parse_args()

    workload_db_descriptor_path = args.workload_db
    suite_db_descriptor_path = args.suite_db
    dbg_lvl = args.debug
    infra_dir = args.scarab_infra

    if infra_dir == None:
        infra_dir = subprocess.check_output(["pwd"]).decode("utf-8").split("\n")[0]

    workloads_data = read_descriptor_from_json(workload_db_descriptor_path, dbg_lvl)
    suite_data = read_descriptor_from_json(suite_db_descriptor_path, dbg_lvl)

    if args.list:
        list_workloads(workloads_data, dbg_lvl)
        exit(0)

    if args.validate != None:
        exp_data = read_descriptor_from_json(args.validate, dbg_lvl)
        validate_simulation(workloads_data, suite_data, exp_data["simulations"], dbg_lvl)
        exit(0)

    if args.group != None:
        exp_data = read_descriptor_from_json(args.group, dbg_lvl)
        print(get_image_name(workloads_data, suite_data, exp_data["simulations"][0]))
        exit(0)
