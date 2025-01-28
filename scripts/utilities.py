#!/usr/bin/python3

# 01/27/2025 Surim Oh | utilities.py

import json
import os
import subprocess

# Print an error message if on right debugging level
def err(msg: str, level: int):
    if level >= 1:
        print("ERR:", msg)

# Print warning message if on right debugging level
def warn(msg: str, level: int):
    if level >= 2:
        print("WARN:", msg)

# Print info message if on right debugging level
def info(msg: str, level: int):
    if level >= 3:
        print("INFO:", msg)

# json descriptor reader
def read_descriptor_from_json(filename="experiment.json", dbg_lvl = 1):
    # Read the descriptor data from a JSON file
    try:
        with open(filename, 'r') as json_file:
            descriptor_data = json.load(json_file)
        return descriptor_data
    except FileNotFoundError:
        err(f"File '{filename}' not found.", dbg_lvl)
        return None
    except json.JSONDecodeError as e:
        err(f"Error decoding JSON in file '{filename}': {e}", dbg_lvl)
        return None

# Verify the given descriptor file
def verify_descriptor(descriptor_data, infra_dir, dbg_lvl = 2):
    ## Check if the provided json describes all the valid data

    # Check the scarab path
    if descriptor_data["scarab_path"] == None:
        err("Need path to scarab path. Set in descriptor file under 'scarab_path'", dbg_lvl)
        exit(1)

    # Check if a correct architecture spec is provided
    if descriptor_data["architecture"] == None:
        err("Need an architecture spec to simulate. Set in descriptor file under 'architecture'. Available architectures are found from PARAMS.<architecture> in scarab repository. e.g) sunny_cove", dbg_lvl)
        exit(1)
    elif not os.path.exists(f"{descriptor_data['scarab_path']}/src/PARAMS.{descriptor_data['architecture']}"):
        err(f"PARAMS.{descriptor_data['architecture']} does not exist. Please provide an available architecture for scarab simulation", dbg_lvl)
        exit(1)

    # Check if a valid workload group is provided
    if descriptor_data["workload_group"] == None:
        err("Need a workload group which is a prefix of docker container name.", dbg_lvl)
        exit(1)
    elif not os.path.exists(f"{infra_dir}/workloads/{descriptor_data['workload_group']}"):
        err(f"{infra_dir}/workloads/{descriptor_data['workload_group']} does not exist. Please provide an available workload group name", dbg_lvl)
        exit(1)

    # Check if a valid workload is provided
    if descriptor_data["workloads_list"] == None:
        err("Need workloads list to simulate. Set in descriptor file under 'workloads_list'", dbg_lvl)
        exit(1)
    else:
        for workload in descriptor_data["workloads_list"]:
            found=False
            with open(f"{infra_dir}/workloads/{descriptor_data['workload_group']}/apps.list", 'r') as f:
                for line in f:
                    if line.strip() == workload:
                        found=True
                        break
                if not found:
                    err(f"{workload} not found in {infra_dir}/workloads/{descriptor_data['workload_group']}/apps.list", dbg_lvl)
                    exit(1)

    # Check experiment doesn't already exists
    experiment_dir = f"{descriptor_data['root_dir']}/simulations/{descriptor_data['experiment']}"
    if os.path.exists(experiment_dir):
        err(f"Experiment '{experiment_name}' already exists. Please try a different name.", dbg_lvl)
        exit(1)

    # Check the simulation mode
    simulation_mode = int(descriptor_data["simulation_mode"])
    if simulation_mode > 5 or simulation_mode <= 0:
        err("0 < simulation_mode <= 5 supported", dbg_lvl)
        exit(1)

    # Check the workload manager
    if descriptor_data["workload_manager"] != "manual" and descriptor_data["workload_manager"] != "slurm":
        err("Workload manager options: 'manual' or 'slurm'.", dbg_lvl)
        exit(1)

    # Check if docker home path is provided
    if descriptor_data["root_dir"] == None:
        err("Need path to docker home directory. Set in descriptor file under 'root_dir'", dbg_lvl)
        exit(1)

    # Check if the provided scarab path exists
    if descriptor_data["scarab_path"] == None:
        err("Need path to scarab directory. Set in descriptor file under 'scarab_path'", dbg_lvl)
        exit(1)
    elif not os.path.exists(descriptor_data["scarab_path"]):
        err(f"{descriptor_data['scarab_path']} does not exist.", dbg_lvl)
        exit(1)

    # Check if trace dir exists
    if descriptor_data["simpoint_traces_dir"] == None:
        err("Need path to simpoints/traces. Set in descriptor file under 'simpoint_traces_dir'", dbg_lvl)
        exit(1)
    elif not os.path.exists(descriptor_data["simpoint_traces_dir"]):
        err(f"{descriptor_data['simpoint_traces_dir']} does not exist.", dbg_lvl)
        exit(1)

    # Check if configurations are provided
    if descriptor_data["configurations"] == None:
        error("Need configurations to simulate. Set in descriptor file under 'configurations'", dbg_lvl)
        exit(1)

# Generate entrypoint command
def generate_docker_entrypoint_command(user, docker_prefix, experiment_name, githash):
    return f"docker run --rm --entrypoint /bin/bash {docker_prefix}:{githash} -c 'mkdir -p /home/{user}/simulations/{experiment_name}/scarab'"

# Generate command to exec in the docker container for a user
def generate_docker_command(user, docker_container_name, docker_prefix, docker_home, scarab_path, simpoint_traces_dir, experiment_name, githash):
    return f"docker run --rm -e user_id=$USER_ID -e group_id=$GROUP_ID -e username={user} -e HOME=/home/{user} --name {docker_container_name} --mount type=bind,source={simpoint_traces_dir},target=/simpoint_traces,readonly --mount type=bind,source={docker_home},target=/home/{user} --mount type=bind,source={scarab_path},target=/home/{user}/simulations/{experiment_name}/scarab {docker_prefix}:{githash} "

# Generate command to do a single run of scarab
def generate_single_scarab_run_command(workload, group, experiment, config_key, config,
                   mode, arch, scarab_path, simpoint, use_traces_simp = 1):
    command = 'run_single_simpoint.sh "' + workload + '" "' + group + '" "" "' + experiment + '/'
    command = command + config_key + '" "' + config + '" "' + mode + '" "' + arch + '" "'
    command = command + str(use_traces_simp) + '" ' + scarab_path + "/src/build/opt/scarab " + str(simpoint)

    return command

# Get workload simpoint ids and their associated weights
def get_simpoints (simpoint_traces_dir, workload, dbg_lvl = 2):
    read_simp_weight_command = f"cat /{simpoint_traces_dir}/{workload}/simpoints/opt.w.lpt0.99"
    read_simp_simpid_command = f"cat /{simpoint_traces_dir}/{workload}/simpoints/opt.p.lpt0.99"

    info(f"Executing '{read_simp_weight_command}'", dbg_lvl)
    weight_out = subprocess.check_output(read_simp_weight_command.split(" ")).decode("utf-8").split("\n")[:-1]

    info(f"Executing '{read_simp_simpid_command}'", dbg_lvl)
    simpid_out = subprocess.check_output(read_simp_simpid_command.split(" ")).decode("utf-8").split("\n")[:-1]

    # Make lut for the weight for each 'index' id
    weights = {}
    for weight_id in weight_out:
        weight, id = weight_id.split(" ")
        weights[id] = float(weight)

    # Make final dictionary associated each simpoint id to its weight
    simpoints = {}
    for simpid_id in simpid_out:
        simpid, id = simpid_id.split(" ")
        simpoints[int(simpid)] = weights[id]

    return simpoints
