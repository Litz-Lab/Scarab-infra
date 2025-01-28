#!/usr/bin/python3

# 10/7/2024 | Alexander Symons | run_slurm.py
# 01/27/2025 | Surim Oh | slurm_runner.py

import os
import random
import subprocess
from utilities import err, warn, info, generate_docker_command, generate_single_scarab_run_command

# Check if a required docker image exists on the provided nodes, return those that are
# Inputs: list of nodes
# Output: list of nodes where the docker image was found
def check_docker_image(nodes, docker_prefix, githash, dbg_lvl = 1):
    try:
        available_nodes = []
        for node in nodes:
            # Check if the image exists
            images = subprocess.check_output(["srun", f"--nodelist={node}", "docker", "images", "|", "grep", f"{docker_prefix}:{githash}"])
            info(f"{images}", dbg_lvl)
            if images == []:
                info(f"Cound't find image {docker_prefix}:{githash} on {node}", dbg_lvl)
                continue

            available_nodes.append(node)

        return available_nodes
    except Exception as e:
        raise

# Check if a container is running on the provided nodes, return those that are
# Inputs: list of nodes, docker container name, path to container mount
# Output: list of nodes where the docker container was found running
# NOTE: Possible race condition where node was available but become full before srun,
# in which case this code will hang.
def check_docker_container_running(nodes, container_name, mount_path, dbg_lvl = 1):
    try:
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
    except Exception as e:
        raise

# Check what containers are running in the slurm cluster
# Inputs: None
# Outputs: a list containing all node names that are currently available or None
def check_available_nodes(dbg_lvl = 1):
    try:
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
    except Exception as e:
        raise

# Copies specified scarab binary, parameters, and launch scripts
# Inputs:   home_dir    - Path to the home directory for the docker container(s)
#           arch        - The architecture to be used for this experiment
#           experiment_name  - The name of the current experiment
#           sacrab_bin  - Path to the scarab binary to use
#           arch_params_path - A path to a custom architectural params file.
#                              Tries to source file from the scarab repo in home_dir if None
# Outputs:  None
# deprecated
def copy_scarab(home_dir: str, arch: str, experiment_name: str, scarab_path: str = None, arch_params_path: str = None, docker_prefix: str = None, dbg_lvl=1):
    ## Copy required scarab files into the experiment folder
    # If scarab binary does not exist in the provided scarab path, build the binary first.
    scarab_bin = f"{descriptor_data['scarab_path']}/src/build/opt/scarab"
    if not os.path.isfile(scarab_bin):
        info(f"Scarab binary not found at '{scarab_bin}', build it first...", dbg_lvl)
        os.system(f"docker run -rm --user={user} --privileged {docker_prefix}_{user} /bin/bash -c \"cd /home/{user}/scarab/src && make clean && make\"")

    experiment_dir = f"{descriptor_data['root_dir']}/{descriptor_data['experiment']}"
    os.system(f"mkdir -p {experiment_dir}/logs/")

    # Copy binary and architectural params to scarab/src
    arch_params = f"{descriptor_data['scarab_path']}/src/PARAMS.{descriptor_data['architecture']}"
    os.system(f"mkdir -p {experiment_dir}/scarab/src/")
    os.system(f"cp {scarab_bin} {experiment_dir}/scarab/src/scarab")
    os.system(f"cp {arch_params} {experiment_dir}/scarab/src")

    # Required for non mode 4. Copy launch scripts from the docker container's scarab repo.
    # NOTE: Could cause issues if a copied version of scarab is incompatible with the version of 
    # the launch scripts in the docker container's repo
    os.system(f"mkdir -p " + home_dir + f"/{experiment_name}/scarab/bin/scarab_globals")
    os.system(f"cp {home_dir}/scarab/bin/scarab_launch.py  {experiment_dir}/scarab/bin/scarab_launch.py ")
    os.system(f"cp {home_dir}/scarab/bin/scarab_globals/*  {experiment_dir}/scarab/bin/scarab_globals/ ")

# Get command to sbatch scarab runs. 1 core each, exclude nodes where container isn't running
def generate_sbatch_command(excludes, experiment_dir):
    # If all nodes are usable, no need to exclude
    if not excludes == set():
        return f"sbatch --exclude {','.join(excludes)} -c 1 -o {experiment_dir}/logs/job_%j.out "

    return f"sbatch -c 1 -o {experiment_dir}/logs/job_%j.out "

# Launch a docker container on one of the available nodes
# deprecated
def launch_docker(infra_dir, docker_home, available_nodes, node=None, dbg_lvl=1):
    try:
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
    except Exception as e:
        raise

# Kills all jobs for experiment_name, if associated with user
def kill_slurm_jobs(user, experiment_name, dbg_lvl = 2):
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

def run_simulation(args, descriptor_data, dbg_lvl = 1):
    architecture = descriptor_data["architecture"]
    docker_prefix = descriptor_data["workload_group"]
    workloads = descriptor_data["workloads_list"]
    experiment_name = descriptor_data["experiment"]
    scarab_mode = descriptor_data["simulation_mode"]
    docker_home = descriptor_data["root_dir"]
    scarab_path = descriptor_data["scarab_path"]
    simpoint_traces_dir = descriptor_data["simpoint_traces_dir"]
    configs = descriptor_data["configurations"]

    try:
        # Get user for commands
        user = subprocess.check_output("whoami").decode('utf-8')[:-1]
        info(f"User detected as {user}", dbg_lvl)

        # Get GitHash
        githash = subprocess.check_output("git rev-parse --short HEAD").decode('utf-8')[:-1]
        info(f"GitHash: {githash}", dbg_lvl)

        # Kill and exit if killing jobs
        if args.kill:
            info(f"Killing all slurm jobs associated with {descriptor_path}", dbg_lvl)
            kill_slurm_jobs(user, experiment_name, dbg_lvl)
            exit(0)

        if args.info:
            info(f"Getting information about all nodes", dbg_lvl)
            available_slurm_nodes, all_nodes = check_available_nodes(dbg_lvl)

            print(f"Checking resource availability of slurm nodes:")
            for node in all_nodes:
                if node in available_slurm_nodes:
                    print(f"\033[92mAVAILABLE:   {node}\033[0m")
                else:
                    print(f"\033[31mUNAVAILABLE: {node}\033[0m")

            # Check what nodes have docker containers that map to same docker home
            mount_path = docker_home[docker_home.rfind('/') + 1:]

            # print(f"\nChecking what nodes have a running container mounted at {mount_path} with name {docker_prefix}_{user}")
            # docker_running = check_docker_container_running(available_slurm_nodes, f"{docker_prefix}_{user}", mount_path, dbg_lvl)
            print(f"\nChecking what nodes have the corresponding image")
            docker_running = check_docker_image(available_slurm_nodes, docker_prefix, githash, dbg_lvl)

            for node in all_nodes:
                if node in docker_running:
                    print(f"\033[92mRUNNING:     {node}\033[0m")
                else:
                    print(f"\033[31mNOT RUNNING: {node}\033[0m")

            exit(0)

        # Get avlailable nodes. Error if none available
        available_slurm_nodes, all_nodes = check_available_nodes(dbg_lvl)
        info(f"Available nodes: {', '.join(available_slurm_nodes)}", dbg_lvl)

        if available_slurm_nodes == []:
            err("Cannot find any running slurm nodes", dbg_lvl)
            exit(1)

        # Try to build the image if one is needed, check it is running
        if docker_running == []:
            warn(f"No nodes found existing docker image with name {docker_prefix}:{githash}", dbg_lvl)

            info ("No nodes have prebuilt image. Building one", dbg_lvl)
            build_image(infra_dir, docker_home, available_slurm_nodes, dbg_lvl)
            docker_running = check_docker_image(available_slurm_nodes, docker_prefix, githash, dbg_lvl)
            info(f"Nodes with docker image found now: {', '.join(docker_running)}", dbg_lvl)

            # If docker image still does not exist, exit
            if docker_running == []:
                err("Error with launched container. Could not detect it after launching", dbg_lvl)
                exit(1)

        info(f"Using docker image with name {docker_prefix}:{githash}", dbg_lvl)

        # Determine nodes without running containers. Launch a container if none found
        excludes = set(all_nodes) - set(docker_running)
        info(f"Excluding following nodes: {', '.join(excludes)}", dbg_lvl)

        # Generate commands for executing in users docker and sbatching to nodes with containers
        experiment_dir = f"{descriptor_data['root_dir']}/simulations/{experiment_name}"
        sbatch_cmd = generate_sbatch_command(excludes, experiment_dir)

        # Iterate over each workload and config combo
        tmp_files = []
        for workload in workloads:
            # Only needed for modes 3 and 4
            simpoints = get_simpoints(simpoint_traces_dir, workload, dbg_lvl)
            for config_key in configs:
                config = configs[config_key]

                for simpoint, weight in simpoints.items():
                    print(simpoint, weight)

                    # Generate a run command
                    docker_cmd = generate_docker_command(user, f"{docker_prefix}_{workload}_{config_key}_{simpoint}_{user}", f"{docker_prefix}", docker_home, scarab_path, simpoint_trace_dir, experiment_name, githash)
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
                        f.write(f"echo \"Running {config_key} {workload} {simpoint}\" \n")
                        f.write("echo \"Running on $(uname -n)\" \n")
                        f.write(f"LOCAL_UID=$(id -u {user})\n")
                        f.write(f"LOCAL_GID=$(id -g {user})\n")
                        f.write("USER_ID=${LOCAL_UID:-9001}\n")
                        f.write("GROUP_ID=${LOCAL_GID:-9001}\n")
                        f.write(docker_cmd + scarab_cmd)

                    os.system(sbatch_cmd + filename)
                    info(f"Running sbatch command '{sbatch_cmd + filename}'", dbg_lvl)

        # Clean up temp files
        for tmp in tmp_files:
            info(f"Removing temporary run script {tmp}", dbg_lvl)
            os.remove(tmp)

        # TODO: check resource capping policies, add kill/info options

        # TODO: (long term) add evalstats to json descriptor to run stats library with PMU counters
    except Exception as e:
        print("An exception occurred:", e)
