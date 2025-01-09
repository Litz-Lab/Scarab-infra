#!/usr/bin/python3

# 10/7/2024 | Alexander Symons | run_slurm.py
# A utility that performs Scarab runs on Slurm clusters using docker containers

import subprocess
import argparse
import json
import os
import random

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

# Check if a container is running on the provided nodes, return those that are
# Inputs: list of nodes, docker container name, path to container mount
# Output: list of nodes where the docker container was found running
# NOTE: Possible race condition where node was available but become full before srun,
# in which case this code will hang.
def check_docker_container_running(nodes, container_name, mount_path, dbg_lvl = 1):

    running_nodes = []
    for node in nodes:
        # Check container is running and no errors
        try:
            mounts = subprocess.check_output(["srun", f"--nodelist={node}", "docker", "inspect", "-f", "'{{ .Mounts }}'", container_name])
        except:
            info(f"Couldn't find container {container_name} on {node}", dbg_lvl)
            continue

        mounts = mounts.decode("utf-8")

        # Check mount matches
        if mount_path not in mounts:
            warn(f"Couldn't find {mount_path} mounted on {node}.\nFound {mounts}", dbg_lvl)
            continue

        running_nodes.append(node)

    # NOTE: Could figure out mount here if all of them agree. Then it wouldn't need to be provided

    return running_nodes


# Check what containers are running in the slurm cluster
# Inputs: None
# Outputs: a list containing all node names that are currently available or None
def check_available_nodes(dbg_lvl = 1):
    # Query sinfo to get all lines with status information for all nodes
    # Ex: [['LocalQ*', 'up', 'infinite', '2', 'idle', 'bohr[3,5]']]
    response = subprocess.check_output(["sinfo", "-N"]).decode("utf-8")
    lines = [r.split() for r in response.split('\n') if r != ''][1:]
    
    # Check each node is up and available
    available = []
    all_nodes = []
    for line in lines:
        node = line[0]
        all_nodes.append(node)

        # Index -1 is STATE. Skip if not partially available
        if line[-1] != 'idle' and line[-1] != 'mix':
            info(f"{node} is not available. It is '{line[-1]}'", dbg_lvl)
            continue

        # Now append node(s) to available list. May be single (bohr3) or multiple (bohr[3,5])
        if '[' in node:
            err(f"'sinfo -N' should not produce lists (such as bohr[2-5]).", dbg_lvl)
            print(f"     problematic entry was '{node}'")
            return None
            
        available.append(node)

    return available, all_nodes

# Copied from `run_exp_using_desciptor.py`
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

# Copies specified scarab binary, parameters, and launch scripts
# Inputs:   home_dir    - Path to the home directory for the docker container(s)
#           arch        - The architecture to be used for this experiment
#           experiment_name  - The name of the current experiment
#           sacrab_bin  - Path to the scarab binary to use
#           arch_params_path - A path to a custom architectural params file.
#                              Tries to source file from the scarab repo in home_dir if None
# Outputs:  None
def copy_scarab(home_dir: str, arch: str, experiment_name: str, scarab_bin: str = None, arch_params_path: str = None, dbg_lvl=1):

    # Experiment directory is at <docker_home>/<experiment>. Should not exist
    experiment_dir = f"{home_dir}/{experiment_name}"
    if os.path.exists(experiment_dir):
        err(f"Experiment '{experiment_name}' already exists. Please try a different name.", dbg_lvl)
        exit(1)

    # If scarab binary not provided, default to the one which was cloned into repo on creation.
    # Check that it exists.
    if not os.path.isfile(scarab_bin):
        err(f"Scarab binary not found at '{scarab_bin}'.", dbg_lvl)
        exit(1)

    # If custom architecural parameters not provided, default to the one which came with scarab repo
    # Check that it exists.
    arch_params = arch_params_path if arch_params_path != None else f"{home_dir}/scarab/src/PARAMS.{arch}"
    if not os.path.isfile(arch_params):
        err(f"Architectural parameters not found at '{arch_params}'.", dbg_lvl)
        print("Note that this script is hard coded to ")
        exit(1)

    os.system(f"mkdir -p {experiment_dir}/logs/")

    # Copy binary and architectural params to scarab/src
    os.system(f"mkdir -p {experiment_dir}/scarab/src/")
    os.system(f"cp {scarab_bin} {experiment_dir}/scarab/src/scarab")
    os.system(f"cp {arch_params} {experiment_dir}/scarab/src")

    # Required for non mode 4. Copy launch scripts from the docker container's scarab repo.
    # NOTE: Could cause issues if a copied version of scarab is incompatible with the version of 
    # the launch scripts in the docker container's repo
    os.system(f"mkdir -p " + home_dir + f"/{experiment_name}/scarab/bin/scarab_globals")
    os.system(f"cp {home_dir}/scarab/bin/scarab_launch.py  {experiment_dir}/scarab/bin/scarab_launch.py ")
    os.system(f"cp {home_dir}/scarab/bin/scarab_globals/*  {experiment_dir}/scarab/bin/scarab_globals/ ")

# Generate command to exec in the docker container for a user
def generate_docker_command(user, docker_container_prefix, root=False):
    if root:
        return f"docker exec --user root --workdir /home/{user} --privileged {docker_container_prefix}_{user} "
    return f"docker exec --user {user} --workdir /home/{user} --privileged {docker_container_prefix}_{user} "

# Generate command to do a single run of scarab
def generate_single_scarab_run_command(workload, group, experiment, config, config_settings, 
                   mode, arch, scarab_path, simpoint, use_traces_simp = 1):
    command = 'run_single_simpoint.sh "' + workload + '" "' + group + '" "" "' + experiment + '/' 
    command = command + config + '" "' + config_settings + '" "' + arch + '" "' 
    command = command + str(use_traces_simp) + '" ' + scarab_path + " " + str(simpoint)

    return command
    
# Get command to sbatch scarab runs. 1 core each, exclude nodes where container isn't running
def generate_sbatch_command(excludes, experiment_dir):
    # If all nodes are usable, no need to exclude
    if not excludes == set():
        return f"sbatch --exclude {','.join(excludes)} -c 1 -o {experiment_dir}/logs/job_%j.out "
    
    return f"sbatch -c 1 -o {experiment_dir}/logs/job_%j.out "

# Launch a docker container on one of the available nodes
def launch_docker(infra_dir, docker_home, available_nodes, node=None, dbg_lvl=1):
    
    # Get the path to the run script
    if infra_dir == ".": run_script = ""
    elif infra_dir[-1] == '/': run_script = infra_dir
    else: run_script = infra_dir + '/'

    # Check if run.sh script exists
    if not os.path.isfile(run_script + "run.sh"):
        err(f"Couldn't find file scarab infra run.sh at {run_script + 'run.sh'}. Check scarab_infra option", dbg_lvl)
        exit(1)

    # Get name of slurm node to spin up
    if node == None:
        spin_up_index = random.randint(0, len(available_nodes)-1)
        spin_up_node = available_nodes[spin_up_index]
    else:
        spin_up_node = node

    # Spin up docker container on that node
    print(f"Spinning up node {spin_up_node}")
    os.system(f"srun --nodelist={spin_up_node} -c 1 {run_script}run.sh -o {docker_home} -b 2")

# Get workload simpoint ids and their associated weights from running node
def get_simpoints (user, workload, node, docker_container_prefix, dbg_lvl = 2):
    # TODO: Check available workloads by doing ls /simpoint_traces
    # Commands parts to get the number associated with each simpoint file and its weight
    read_simp_weight_command = f"cat /simpoint_traces/{workload}/simpoints/opt.w.lpt0.99"
    read_simp_simpid_command = f"cat /simpoint_traces/{workload}/simpoints/opt.p.lpt0.99"
    docker_cmd = generate_docker_command(user, docker_container_prefix)
    slurm_cmd = f"srun --nodelist={','.join(node)} -c 1 "

    # Get weights associated with 'index' id
    weight_cmd = f"{slurm_cmd}{docker_cmd}{read_simp_weight_command}"
    info(f"Executing '{weight_cmd}'", dbg_lvl)
    wieght_out = subprocess.check_output(weight_cmd.split(" ")).decode("utf-8").split("\n")[:-1]

    # Get simpoint id associated with 'index' id
    simpid_cmd = f"{slurm_cmd}{docker_cmd}{read_simp_simpid_command}"
    info(f"Executing '{simpid_cmd}'", dbg_lvl)
    simpid_out = subprocess.check_output(simpid_cmd.split(" ")).decode("utf-8").split("\n")[:-1]
    
    # Make lut for the weight for each 'index' id
    weights = {}
    for weight_id in wieght_out:
        weight, id = weight_id.split(" ")
        weights[id] = float(weight)
    
    # Make final dictionary associated each simpoint id to its weight
    simpoints = {}
    for simpid_id in simpid_out:
        simpid, id = simpid_id.split(" ")
        simpoints[int(simpid)] = weights[id]

    return simpoints

# Kills all jobs for experiment_name, if associated with user
def kill_jobs(user, experiment_name, dbg_lvl = 2):
    # Format is JobID Name
    response = subprocess.check_output(["squeue", "-u", user, "--Format=JobID,Name:90"]).decode("utf-8")
    lines = [r.split() for r in response.split('\n') if r != ''][1:]
    
    # Filter to entries assocaited with this experiment, and get job ids
    lines = list(filter(lambda x:experiment_name in x[1], lines))
    job_ids = list(map(lambda x:int(x[0]), lines))

    # Kill each job
    info(f"Killing jobs with slurm job ids: {', '.join(map(str, job_ids))}", dbg_lvl)
    for id in job_ids:
        try:
            subprocess.check_call(["scancel", "-u", user, str(id)])
        except subprocess.CalledProcessError as e:
            err(f"Couldn't cancel job with id {id}. Return code: {e.returncode}", dbg_lvl)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Runs scrab on a slurm network')

    # Add arguments
    parser.add_argument('-d','--descriptor_name', required=True, help='Experiment descriptor name. Usage: -d exp2.json')
    parser.add_argument('-k','--kill', required=False, default=False, action=argparse.BooleanOptionalAction, help='Don\'t launch jobs from descriptor, kill running jobs as described in descriptor')
    parser.add_argument('-i','--info', required=False, default=False, action=argparse.BooleanOptionalAction, help='Get info about all nodes and if they have containers')
    parser.add_argument('-l','--launch', required=False, default=None, help='Launch a docker container on a node. Use ? to pick a random node. Usage: -l bohr1')
    parser.add_argument('-dir','--home_dir', required=False, default=None, help='Home directory for the docker containers')
    parser.add_argument('-m','--scarab_mode', required=False, type=int, default=4, help='Scarab mode. Usage -m 2')
    parser.add_argument('-s','--scarab_bin', required=False, default=None, help='Scarab binary. Path to custom binary to be used')
    parser.add_argument('-a','--arch_params', required=False, default=None, help='Path to a custom <architecture>.PARAMS file for scarab')
    parser.add_argument('-dbg','--debug', required=False, type=int, default=2, help='1 for errors, 2 for warnings, 3 for info')
    parser.add_argument('-si','--scarab_infra', required=False, default=None, help='Path to scarab infra repo to launch new containers')
    parser.add_argument('-pref','--docker_prefix', required=False, default=None, help='Prefix of docker container. Should be found in apps.list. Can be confirmed using docker ps -a and using prefix from {prefix}_{username} under NAMES')

    # Parse the command-line arguments
    args = parser.parse_args()

    # Assign clear names to arguments
    descriptor_path = args.descriptor_name
    docker_home = args.home_dir
    scarab_mode = args.scarab_mode
    arch_params_file = args.arch_params
    dbg_lvl = args.debug
    infra_dir = args.scarab_infra

    if scarab_mode != 4:
        err("Scarab mode other than 4 not implemented", dbg_lvl)
        exit(1)

    if infra_dir == None:
        infra_dir = subprocess.check_output(["pwd"]).decode("utf-8").split("\n")[0]

    # Read descriptor json and extract important data
    descriptor_data = read_descriptor_from_json(descriptor_path, dbg_lvl)
    architecture = descriptor_data["architecture"]
    experiment_name = descriptor_data["experiment"]
    configs = descriptor_data["configurations"]
    workloads = descriptor_data["workloads_list"]
    experiment_scarab = descriptor_data.get("scarab_path")

    # Get user for commands
    user = subprocess.check_output("whoami").decode('utf-8')[:-1]
    info(f"User detected as {user}", dbg_lvl)

    # Kill and exit if killing jobs
    if args.kill:
        info(f"Killing all slurm jobs associated with {descriptor_path}", dbg_lvl)
        kill_jobs(user, experiment_name, dbg_lvl)
        exit(0)

    # Get path to the docker contianers' home directory
    if docker_home == None: # Try to get from descriptor if not set manually
        docker_home = descriptor_data.get("docker_home")

    if docker_home == None:
        err("Need path to docker home directory. Set in descriptor file under 'docker_home' or in --home_dir argument", dbg_lvl)
        exit(1)

    # Get scarab binary path
    # Priority is: 1) command line override, 2) experiment file, 3) docker prebuilt version 
    if args.scarab_bin != None:
        scarab_bin = args.scarab_bin
        if experiment_scarab != None:
            warn(f"Scarab bin provided in descriptor was overriden by argument. Using '{scarab_bin}'", dbg_lvl)
    elif experiment_scarab != None:
        scarab_bin = experiment_scarab
        info(f"Scarab bin found in descriptor ({scarab_bin})", dbg_lvl)
    else:
        scarab_bin = f"{docker_home}/scarab/src/scarab"
        info(f"Scarab bin not provided. Trying to use scarab build from docker home ({docker_home})", dbg_lvl)

    # Get docker container prefix (x_userame from container name. Eg: allbench_traces)
    # TODO: Try to determine container name from workload, for now use allbench
    if args.docker_prefix != None:
        docker_prefix = args.docker_prefix
    elif descriptor_data.get("docker_prefix") != None:
        docker_prefix = descriptor_data.get("docker_prefix")
    else:
        # NOTE: Temporarily hardcoded to allbench
        docker_prefix = "allbench_traces"

    if args.info:
        info(f"Getting information about all nodes", dbg_lvl)    
        available_slurm_nodes, all_nodes = check_available_nodes(dbg_lvl)
        
        print(f"Checking resource availability of slurm nodes:")
        for node in all_nodes:
            if node in available_slurm_nodes:
                print(f"\033[92mAVAILABLE:   {node}\033[0m")
            else:
                print(f"\033[31mUNAVAILABLE: {node}\033[0m")

        # Check what nodes have docker conatiners that map to same docker home
        mount_path = docker_home[docker_home.rfind('/') + 1:]

        print(f"\nChecking what nodes have a running container mounted at {mount_path} with name {docker_prefix}_{user}")
        docker_running = check_docker_container_running(available_slurm_nodes, f"{docker_prefix}_{user}", mount_path, dbg_lvl)

        for node in all_nodes:
            if node in docker_running:
                print(f"\033[92mRUNNING:     {node}\033[0m")
            else:
                print(f"\033[31mNOT RUNNING: {node}\033[0m")

        exit(0)

    if args.launch != None:
        if args.launch == "?":
            available_slurm_nodes, all_nodes = check_available_nodes(dbg_lvl)
            launch_docker(infra_dir, docker_home, available_slurm_nodes, dbg_lvl=dbg_lvl)
            exit(0)

        print(f"Launching a docker container on {args.launch}")
        # Available nodes is not important when launching a specific node
        launch_docker(infra_dir, docker_home, None, args.launch, dbg_lvl) 
        exit(0)
#         try:
#             with open(f"{infra_dir}/apps.list", "r") as f:
#                 trim_nl = lambda x : x.split("\n")[0]
#                 lines = [line for line in map(trim_nl, f.readlines()) if line != ""]
#                 if len(lines) == 1:
#                     docker_prefix = lines[0]
#                     info(f"Docker prefix {docker_prefix} from apps.list", dbg_lvl)

#         except FileNotFoundError as e:
#             err("Couldn't find any docker prefix as argument or in descriptor. \
# Docker prefix should be the app groupname, found in the apps.list file and the \
# docker container name (with format {prefix}_{user}). A common example would be 'docker_traces'", 
#                 dbg_lvl)
#             exit(1)

    # Check experiment doesn't already exists
    experiment_dir = f"{docker_home}/{experiment_name}"
    
    if os.path.exists(experiment_dir):
        err(f"Experiment '{experiment_name}' already exists. Please try a different name.", dbg_lvl)
        exit(1)
    
    # Get avlailable nodes. Error if none available
    available_slurm_nodes, all_nodes = check_available_nodes(dbg_lvl)
    info(f"Available nodes: {', '.join(available_slurm_nodes)}", dbg_lvl)

    if available_slurm_nodes == []:
        err("Cannot find any running slurm nodes", dbg_lvl)
        exit(1)

    # Check what nodes have docker conatiners that map to same docker home
    mount_path = docker_home[docker_home.rfind('/') + 1:]
    docker_running = check_docker_container_running(available_slurm_nodes, f"{docker_prefix}_{user}", mount_path, dbg_lvl)
    info(f"Nodes with docker container running: {', '.join(docker_running)}", dbg_lvl)

    # docker_traces_aesymons
    # Try to launch container if one is needed, check it is running
    if docker_running == []:
        warn(f"No nodes found running docker container with name {docker_prefix}_{user}", dbg_lvl)

        info("No nodes are running docker nodes. Launching one", dbg_lvl)
        launch_docker(infra_dir, docker_home, available_slurm_nodes, dbg_lvl)
        docker_running = check_docker_container_running(available_slurm_nodes, f"{docker_prefix}_{user}", mount_path, dbg_lvl)
        info(f"Nodes with docker container running now: {', '.join(docker_running)}", dbg_lvl)

        # If docker container is still not running exit
        if docker_running == []:
            err("Error with launched container. Could not detect it after launching", dbg_lvl)
            exit(1)

    info(f"Using docker container with name {docker_prefix}_{user}", dbg_lvl)

    # Determine nodes without running containers. Launch a container if none found
    excludes = set(all_nodes) - set(docker_running)
    info(f"Excluding following nodes: {', '.join(excludes)}", dbg_lvl)

    # exit(1)

    # Copy required scarab files into the experiment folder
    copy_scarab(docker_home, architecture, experiment_name, scarab_bin, arch_params_file)

    # Generate commands for executing in users docker and sbatching to nodes with containers
    docker_cmd = generate_docker_command(user, f"{docker_prefix}")
    chmod_docker_cmd = generate_docker_command(user, f"{docker_prefix}", root=True)
    sbatch_cmd = generate_sbatch_command(excludes, experiment_dir)

    # Iterate over each workload and config combo
    tmp_files = []
    cmd_queue = []
    for workload in workloads:
        # Only needed for modes 3 and 4
        simpoints = get_simpoints(user, workload, docker_running, docker_prefix, dbg_lvl)
        for config_key in configs:
            config = configs[config_key]

            for simpoint, weight in simpoints.items():
                print(simpoint, weight)

                # Generate a run command
                scarab_cmd = generate_single_scarab_run_command(workload, docker_prefix, experiment_name, config_key, config, scarab_mode, architecture, f"/home/{user}/{experiment_name}/scarab", simpoint)
                info(f"Running '{docker_cmd + scarab_cmd}'", dbg_lvl)

                # TODO: Notification when a run fails, point to output file and command that caused failure
                # Add help (?)  
                # Look into squeue -o https://slurm.schedmd.com/squeue.html
                # Look into resource allocation
            
                # TODO: Rewrite with sbatch arrays

                # Create temp file with run command and run it
                filename = f"{experiment_name}_{workload}_{config_key.replace("/", "-")}_{simpoint}_tmp_run.sh"
                tmp_files.append(filename)
                with open(filename, "w") as f:
                    f.write("#!/bin/bash \n")
                    f.write(f'echo "Running {config_key} {workload} {simpoint}" \n')
                    f.write('echo "Running on $(uname -n)" \n')
                    f.write(chmod_docker_cmd + "chmod +x /usr/local/bin/run_single_simpoint.sh \n")
                    f.write(docker_cmd + scarab_cmd)

                cmd_queue.append(sbatch_cmd + filename)
                
    
    for cmd in cmd_queue:
        os.system(cmd)
        info(f"Running sbatch command '{cmd}'", dbg_lvl)

    # Clean up temp files
    for tmp in tmp_files:
        info(f"Removing temporary run script {tmp}", dbg_lvl)
        os.remove(tmp)

    # TODO: check resource capping policies, add kill/info options

    # TODO: (long term) add evalstats to json descriptor to run stats library with PMU counters