# Scarab-infra
scarab-infra is an infrastructure that serves an environment where a user analyzes CPU metrics of a workload, applies [SimPoint](https://cseweb.ucsd.edu/~calder/simpoint/) method to exploit program phase behavior, collects execution traces, and simulates the workload by using [scarab](https://github.com/Litz-Lab/scarab) microprocessor simulator. The environment is buildable via [Docker](https://www.docker.com/).

This tool is mainly used for the following three scenarios where CPU architect works on CPU performance for datacenter workloads.
1) Simulate and evaluate a customized modern microprocessor by using scarab CPU simulator and datacenter workloads' execution traces (trace-driven simulation) + plot CPU metrics from the simulation results.
2) Run a datacenter workload itself or run scarab simulation of the workload in execution-driven mode.
3) Analyze CPU metrics of a datacenter workload, extract its program phase behavior, and collect its exection traces.

In this README, 1) and 2) are described with step-by-step instructions by using Slurm workload manager.

There are four ways to run Scarab: 1) execution-driven w/o SimPoint 2) trace-based w/o SimPoint 3) execution-driven w/ SimPoint 4) trace-based w/ SimPoint. The execution-driven simulation runs the application binary directly without using traces while the trace-based simulation needs collected traces to run the application. SimPoints are used for fast-forwarding on the execution-driven run and for collecting traces/simulating on the trace-based run.
The list of the Scarab parameters should be given to generate parameter descriptor file in `<experiment_name>.json`. Please refer to the `./json/exp.json` files for the examples.

The following steps are for the fourth running scenario (trace-based w/ SimPoint) with the traces of datacenter workloads we already collected.

## Requirements
1. Install Docker on all the Slurm nodes based on the instructions from official [docker docs](https://docs.docker.com/engine/install/).
2. To run scarab in a docker container, the host machine should use non-root user and the user has a proper GitHub setup to access https://github.com/Litz-Lab/scarab.
To run docker as a non-root user, run ([ref](https://stackoverflow.com/questions/48957195/how-to-fix-docker-got-permission-denied-issue)):
   ```
   sudo chmod 666 /var/run/docker.sock
   ```
Generate a new SSH key and add it to the machine's SSH agent, then add it to your GitHub account ([link](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=linux)).
3. Slurm runner must run on a slurm cluster node. To install Slurm, see the [Slurm Installation Guide](slurm_install_guide.md)
