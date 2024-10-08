# Scarab-infra
Dockerfiles of docker images running data center workloads and run Scarab simulation

## Docker setup
Install Docker based on the instructions from official [docker docs](https://docs.docker.com/engine/install/).

## Requirements
You need a Linux system and Docker installed in it.
The provided Docker container has been tested on Ubuntu Linux 20.04 and 24.04. In principle, you should be able to run the Linux Docker container on Windows and Mac as well, but it a) requires a VM (e.g. the one coming with Docker Desktop) and b) you may have to change some of the scripts/commands to set it up.
To run scarab in a docker container, the host machine should use non-root user and the user has a proper GitHub setup to access https://github.com/Litz-Lab/scarab.
To run docker as a non-root user, run: "sudo chmod 666 /var/run/docker.sock" (ref: https://stackoverflow.com/questions/48957195/how-to-fix-docker-got-permission-denied-issue)
To generate a new SSH key and it to the machine's SSH agent: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=linux
Add a new SSH key to your GitHub account: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account?platform=linux

## Clean up any cached docker container/image/builds
```
docker stop cse220_$USER
docker rm cse220_$USER
docker rmi cse220_:latest
docker system prune
```

## 1. Build a Docker image and run a container of a built image where all the traces are available and ready to run Scarab (takes > 5 min depending on your system)
```
./run.sh -o <path_to_mount_docker_home> -b 2
```
For example, on a Linux system,
```
./run.sh -o /home/$USER/cse220_home -b 2
```
On a Mac system,
```
./run.sh -o /Users/$USER/cse220_home -b 2
```

You should see a docker container `cse220_$USER` running. Check with the following command.
```
docker ps
```
You will also see `scarab` repository cloned and successfully built at `/home/$USER/cse220_home` or `/Users/$USER/cse220_home`

## 2. Run Scarab simulations by using a descriptor file
The example file descriptor for the simulation scenarios for the lab is already in `cse220/lab1.json`
Open and edit the json file to select workloads and scenarios before running it.
Run the following command with <experiment> name for -e. The simulations using memtraces for the selected SPEC benchmarks should be launched with a simulation mode `220`.
On a Linux system,
```
./run.sh -o /home/$USER/cse220_home -s 220 -e lab1
```
On a Mac system,
```
./run.sh -o /Users/$USER/cse220_home -s 220 -e lab1
```
The script will launch 'max_processes' Scarab simulations in background until it runs all the different scenarios x workloads. You can change the maximum number (10 by default) of simulation processes by changing line 55 in `run_exp_using_descriptor.py`. You can check if all the simulations are over by checking if there is any `scarab` process running (UNIX 'top' command).

## 3. Check the results
If you don't see any `scarab` process running, you are now ready to check the simulation results.
You can find the simulation results at `/home/$USER/cse220_home/exp/simulations` or `/Users/$USER/cse220_home/exp/simulations`

On a Linux system,
```
cd /home/$USER/cse220_home/exp/simulations
ls
```
On a Mac system,
```
cd /Users/$USER/cse220_home/exp/simulations
ls
```
If the simulation has been successfully completed, you should see `fetch.stat.0.csv` and `memory.stat.0.csv` inside each machine configuration where the entire path you can find them is `/home/$USER/cse220_home/exp/simulations/500.perlbench_r/lab1/<config_name>/fetch.stat.0.csv`.

## 4. Plot the figures
On a Linux system,
```
./run.sh -o /home/$USER/cse220_home -e lab1 -p 1
```
On a Mac system,
```
./run.sh -o /Users/$USER/cse220_home -e lab1 -p 1
```

You will find `/home/$USER/cse220_home/plot/lab1/FigureA.png` or `/Users/$USER/cse220_home/plot/lab1/FigureB.png` generated.

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
