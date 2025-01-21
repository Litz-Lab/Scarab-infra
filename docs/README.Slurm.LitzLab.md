# Scarab-infra
scarab-infra is an infrastructure that serves an environment where a user analyzes CPU metrics of a workload, applies [SimPoint](https://cseweb.ucsd.edu/~calder/simpoint/) method to exploit program phase behavior, collects execution traces, and simulates the workload by using [scarab](https://github.com/Litz-Lab/scarab) microprocessor simulator. The environment is buildable via [Docker](https://www.docker.com/).

This tool is mainly used for the following three scenarios where CPU architect works on CPU performance for datacenter workloads.
1) Simulate and evaluate a customized modern microprocessor by using scarab CPU simulator and datacenter workloads' execution traces (trace-driven simulation) + plot CPU metrics from the simulation results.
2) Run a datacenter workload itself or run scarab simulation of the workload in execution-driven mode.
3) Analyze CPU metrics of a datacenter workload, extract its program phase behavior, and collect its exection traces.

In this README, 1) and 2) are described with step-by-step instructions by using Slurm workload manager on NFS UCSC.

There are four ways to run Scarab: 1) execution-driven w/o SimPoint 2) trace-based w/o SimPoint 3) execution-driven w/ SimPoint 4) trace-based w/ SimPoint. The execution-driven simulation runs the application binary directly without using traces while the trace-based simulation needs collected traces to run the application. SimPoints are used for fast-forwarding on the execution-driven run and for collecting traces/simulating on the trace-based run.
The list of the Scarab parameters should be given to generate parameter descriptor file in `<experiment_name>.json`. Please refer to the `./json/exp.json` files for the examples.

The following steps are for the fourth running scenario (trace-based w/ SimPoint) with the traces of datacenter workloads we already collected.

## Requirements
1. Docker should be installed in all the machines (Slurm nodes) in NFS. If not, install Docker based on the instructions from official [docker docs](https://docs.docker.com/engine/install/).
2. To run scarab_ll non-public branches in a docker container, the host machine should have ssh private key ~/.ssh/id_rsa permitted to clone 'scarab_ll' github repository.
3. Slurm runner must run on a slurm cluster node. To install Slurm, see the [Slurm Installation Guide](slurm_install_guide.md)
Only use this for images that are private and will always be! The private key will be visible in the container.
3. To run the SPEC2017 benchmarks, the host machine should have the image `cpu2017-1_0_5.iso` under `SPEC2017/`.
4. To access traces and simpoints already residing in UCSC LDAP (allbench_traces), you need a BSOE account.

## Running on a Slurm cluster
This script must be run on a slurm cluster connected to the NFS. It will spawn all simpoints as slurm jobs to run on any node where the docker container is found. If no nodes are found it will attempt launch a container on one of the nodes using this Scarab-Infra repository (which should be on the nfs to launch containers from).

### Location of stats, parameters file, and scarab binary
The stats are moved to a different location for the slurm runner. The stats for an experiment can be found in your docker home folder, under the following path:
`/docker_home/experiment_name/configuration_name/workload/simpoint_id/`

The file containing the architectural parameters and the scarab binary used by an experiment can be found at the following path:
`/docker_home/experiment_name/src/`

### New descriptor file options
These options should not affect functionality of the existing infrastructure. New options are:

Scarab path:
Ex: `"scarab_path": "/path/to/scarab_bin"`
This is a path to the scarab binary to be used. Absolute path recommended

Docker home:
Ex: `"docker_home": "path/to/docker/container/home"`
This is the path to the 'home' directory where all docker containers are linked. Should have been provided to build command via '-o' option

Docker prefix:
Ex: `"docker_prefix": "app_groupname"`
This corresponds to the APP_GROUPNAME used in the existing infrastructure, which comes from `apps.list`. This is used when creating docker containers using `./run.sh -o .. -b 2`, which produces containers with `{APP_GROUPNAME}_{USERNAME}`. You can check these container names with `docker ps -a`. This APP_GROUPNAME is provided via docker_prefix so the scarab launch script can detect your containers and run containers in them. An example of an app groupname would be `allbench_traces`

### Quickstart

#### 1. Build a container
Follow the normal instructions for building a container. Make note of A) the path provided via -o, and B) the name placed in apps.list (Ex: `allbench_traces` when using slurm on the Litz lab NFS  ).
Note that the path of the home directory should be on NFS

#### 2. Configure desciptor file
Open the slurm_exp.json file and place the docker home directory (the path provided via -o in the previous step) as the "docker_home" option. Then put the name from apps.list into the json file under "docker_prefix".

#### 3. Run the experiment
Now run `python3 run_slurm.py -dbg 3 -d slurm_exp.json`. Check the running slurm jobs with `squeue`. After it completes, the statistics should be placed in your docker home folder, under the experiment name. In this folder you will see sub-folders for the specified configurations, which contain folders for the workloads, which contain folders for individual simpoint's stats.

### Troubleshooting
Note that the slurm runner requires a new script to be installed into the docker container, which seems to not install correctly sometimes. To fix this, run the following command:
`./update_scripts.sh <container_name>`

### Cancel an experiment
If you want to kill an experiment you previously launched, you can rerun the command used to launch it with `--kill`. Using the launch command of `python3 run_slurm.py -dbg 3 -d slurm_exp.json` as an example, you can cancel it with `python3 run_slurm.py -dbg 3 -d slurm_exp.json --kill`.

### Slurm runner Usage
usage: run_slurm.py [-h] -d DESCRIPTOR_NAME 
                    [-k | --kill | --no-kill]
                    [-dir HOME_DIR] 
                    [-m SCARAB_MODE] 
                    [-s SCARAB_BIN] 
                    [-a ARCH_PARAMS] 
                    [-dbg DEBUG] 
                    [-si SCARAB_INFRA] 
                    [-pref DOCKER_PREFIX]

Runs scrab on a slurm network

options:
  -h, --help            show this help message and exit
  -d DESCRIPTOR_NAME, --descriptor_name DESCRIPTOR_NAME
                        Experiment descriptor name. Usage: -d exp2.json
  -k, --kill, --no-kill
                        Don't launch jobs from descriptor, kill running jobs as described in descriptor
  -dir HOME_DIR, --home_dir HOME_DIR
                        Home directory for the docker containers
  -m SCARAB_MODE, --scarab_mode SCARAB_MODE
                        Scarab mode. Usage -m 2
  -s SCARAB_BIN, --scarab_bin SCARAB_BIN
                        Scarab binary. Path to custom binary to be used
  -a ARCH_PARAMS, --arch_params ARCH_PARAMS
                        Path to a custom <architecture>.PARAMS file for scarab
  -dbg DEBUG, --debug DEBUG
                        1 for errors, 2 for warnings, 3 for info
  -si SCARAB_INFRA, --scarab_infra SCARAB_INFRA
                        Path to scarab infra repo to launch new containers
  -pref DOCKER_PREFIX, --docker_prefix DOCKER_PREFIX
                        Prefix of docker container. Should be found in apps.list. Can be confirmed using docker ps -a and using prefix from {prefix}_{username} under NAMES

The -d (--descriptor_name) is the only required argument if the following options are defined in the descriptor file:
scarab_path - Path to scarab binary. --scarab_bin value will be used instead of the descriptor values if the argument is provided. If neither are provided, the binary in the docker home will be used
docker_home - Path to the home directory used by all docker containers (across all slurm nodes)
docker_prefix - Found in the name of the docker container. It is the part before the username, and is usually set based on the value in apps.list. An example would be allbench_traces. To determine this value, run `docker ps -a` and from names of format {APP_GROUPNAME}_{USERNAME} the prefix will be the {APP_GROUPNAME} portion.

# Publications

```
@inproceedings{oh2024udp,
  author = {Oh, Surim and Xu, Mingsheng and Khan, Tanvir Ahmed and Kasikci, Baris and Litz, Heiner},
  title = {UDP: Utility-Driven Fetch Directed Instruction Prefetching},
  booktitle = {Proceedings of the 51st International Symposium on Computer Architecture (ISCA)},
  series = {ISCA 2024},
  year = {2024},
  month = jun,
}
```
