#!/usr/bin/python3

# 01/27/2025 | Surim Oh | local_runner.py

import os
import subprocess
from utilities import err, warn, info, get_simpoints, generate_docker_entrypoint_command, generate_docker_command, generate_single_scarab_run_command

# Kills all local jobs for experiment_name, if associated with user
def kill_local_jobs(user, experiment_name, dbg_lvl = 2):
    found_processes = []
    for process in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            if process.info['cmdline'] and any("scarab" in arg for arg in process.info['cmdline']):
                found_processes.append(process)
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass

    if not found_processes:
        print(f"No processes found with command including: {search_string}")
        return

    confirm = input("Do you want to kill these processes? (y/n): ").lower()
    if confirm == 'y':
        for proc in found_processes:
            try:
                proc.terminate()  # Gracefully terminate the process
                proc.wait(5)     # Wait for the process to terminate
                print(f"Successfully terminated PID {proc.info['pid']}")
            except psutil.TimeoutExpired:
                print(f"Force killing PID {proc.info['pid']}")
                proc.kill()  # Force kill the process
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                print(f"Unable to terminate PID {proc.info['pid']}")
    else:
        print("Operation canceled.")

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
        try:
            githash = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"]).decode("utf-8").strip()
            info(f"Git hash: {githash}", dbg_lvl)
        except FileNotFoundError:
            err("Error: 'git' command not found. Make sure Git is installed and in your PATH.")
        except subprocess.CalledProcessError:
            err("Error: Not in a Git repository or unable to retrieve Git hash.")


        # Kill and exit if killing jobs
        if args.kill:
            info(f"Killing all simulation jobs associated with {descriptor_path}", dbg_lvl)
            kill_local_jobs(user, experiment_name, dbg_lvl)
            exit(0)

        if args.info:
            err(f"--info option is only available for slurm mode", dbg_lvl)
            exit(1)

        experiment_dir = f"{descriptor_data['root_dir']}/simulations/{experiment_name}"
        entry_cmd = generate_docker_entrypoint_command(user, f"{docker_prefix}", experiment_name, githash)
        info(f"Running '{entry_cmd}'", dbg_lvl)
        os.system(entry_cmd)

        # Iterate over each workload and config combo
        available_cores = os.cpu_count()
        max_processes = int(available_cores * 0.9)
        processes = set()
        max_processes = 0.9
        tmp_files = []
        for workload in workloads:
            simpoints = get_simpoints(simpoint_traces_dir, workload, dbg_lvl)
            for config_key in configs:
                config = configs[config_key]

                for simpoint, weight in simpoints.items():
                    print(simpoint, weight)

                    # Generate a run command
                    docker_cmd = generate_docker_command(user, f"{docker_prefix}_{workload}_{config_key}_{simpoint}_{user}", f"{docker_prefix}", docker_home, scarab_path, simpoint_traces_dir, experiment_name, githash)
                    scarab_cmd = generate_single_scarab_run_command(workload, docker_prefix, experiment_name, config_key, config, scarab_mode, architecture, f"/home/{user}/{experiment_name}/scarab", simpoint)
                    info(f"Running '{docker_cmd + scarab_cmd}'", dbg_lvl)

                    # Create temp file with run command and run it
                    filename = f"{experiment_name}_{workload}_{config_key.replace("/", "-")}_{simpoint}_tmp_run.sh"
                    tmp_files.append(filename)
                    with open(filename, "w") as f:
                        f.write("#!/bin/bash\n")
                        f.write(f"echo \"Running {config_key} {workload} {simpoint}\"\n")
                        f.write("echo \"Running on $(uname -n)\"\n")
                        f.write("LOCAL_UID=$(id -u $USER)\n")
                        f.write("LOCAL_GID=$(id -g $USER)\n")
                        f.write("USER_ID=${LOCAL_UID:-9001}\n")
                        f.write("GROUP_ID=${LOCAL_GID:-9001}\n")
                        f.write(docker_cmd + scarab_cmd)

                    command = '/bin/bash ' + filename
                    process = subprocess.Popen("exec " + command, stdout=subprocess.PIPE, shell=True)
                    processes.add(process)
                    info(f"Running command '{command}'", dbg_lvl)
                    while len(processes) >= max_processes:
                        # Loop through the processes and wait for one to finish
                        for p in processes.copy():
                            if p.poll() is not None: # This process has finished
                                p.wait() # Make sure it's really finished
                                processes.remove(p) # Remove from set of active processes
                                break # Exit the loop after removing one process

        print("Wait processes...")
        for p in processes:
            p.wait()

        # Clean up temp files
        for tmp in tmp_files:
            info(f"Removing temporary run script {tmp}", dbg_lvl)
            # os.remove(tmp)

    except Exception as e:
        print("An exception occurred:", e)
        for p in processes:
            p.kill()
