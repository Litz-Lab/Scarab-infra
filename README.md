# Scarab-infra

scarab-infra is a set of tools that automate the execution of Scarab simulations. It utilizes [Docker](https://www.docker.com/) and [Slurm](https://slurm.schedmd.com/documentation.html) to effectively simulate applications according to the [SimPoint](https://cseweb.ucsd.edu/~calder/simpoint/) methodology. Furthermore, scarab-infra provides tools to analyze generated simulation statistics and to obtain simpoints and execution traces from binary applications.

## Requirements
1. Install Docker [docker docs](https://docs.docker.com/engine/install/) and python docker library.
```
apt-get install python3-docker
```
2. Configure Docker to run as non-root user ([ref](https://stackoverflow.com/questions/48957195/how-to-fix-docker-got-permission-denied-issue)):
```
sudo chmod 666 /var/run/docker.sock
```
3. Add the SSH key of the machine(s) running the Docker container to your GitHub account ([link](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=linux)).
4. Place simpointed instruction traces into $SIMPOINT_TRACES_DIR. scarab-infra offers prepackaged traces that can be downloaded as follows:
```
cd /home/$USER/simpoint_traces
gdown https://drive.google.com/uc?id=1tfKL7wYK1mUqpCH8yPaPVvxk2UIAJrOX
tar -xzvf simpoint_traces.tar.gz
```
5. Optional: Install [Slurm](docs/slurm_install_guide.md)

## Set up the environment (Docker image)
### Alternative 1. Download a pre-built Docker image
### Alternative 2. Build your own Docker image
```
./run.sh -b $WORKLOAD_GROUPNAME
```

### List available workload group name
```
./run.sh --list
```

## Run a Scarab experiment

1. Setup a new experiment descriptor
```
cp json/exp.json json/your_experiment.json
```
2. Edit your_experiment.json to describe your experiment. Please refer to json/exp.json for the describtion. To set the 'workload manager' = slurm, Slurm should be installed.
3. Run all experiments
```
./run.sh --simulation your_experiment
```
The script will launch all Scarab simulations in parallel (one process per simpoint). You can check if the experiment is complete if there are no active scarab process running (UNIX 'top' command).

## Check the info/status of the experiment
```
./run.sh --status your_experiment
```

## Kill the experiment
```
./run.sh --kill your_experiment
```

## Run an interactive shell of a docker container for the purpose of debugging/development
```
./run.sh --run your_experiment
```

## Modify the source code and rebuild scarab
A user can update scarab and rebuild for further simulation. Scarab can be updated either 'inside' or 'outside' the container. To exploit already-set simulation/building environment, scarab build itself should be done 'inside' the container.
### Alternative 1. Start an interactive container with pre-installed Scarab environment
```
./run.sh --run your_experiment
cd /home/$USER/{experiment}/scarab/src
make clean && make
```
### Alternative 2. Work outside of the container
When you modify scarab outside the container, cd to the path you provided for 'scarab_path' in your_experiment.json, and modify it.
```
cd /home/$USER/src/scarab
```

## Clean up any cached docker container/image/builds
```
./run.sh -c -w allbench
```

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
