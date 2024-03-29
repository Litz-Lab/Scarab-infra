# Scarab-infra
Dockerfiles of docker images running data center workloads and run Scarab simulation

## Docker setup
Install Docker based on the instructions from official [docker docs](https://docs.docker.com/engine/install/).

## 1. Build a Docker image and run a container of a built image where all the traces/simpoints are available and ready to run Scarab
```
./run.sh -o <path_to_mount_docker_home> -b 2
```
For example,
```
./run.sh -o /home/$USER/isca2024_home -b 2
```

## 2. Run Scarab simulations by using a descriptor file
The file descriptor for all the simulation scenarios for Artifact Evaluation is already in isca2024_udp/isca.json and isca2024_udp/isca.pt.json
The simulations using memtrace or pt traces should be launched separately with different simulation mode (4 : memtrace, 5 : PT trace)
Run the following command with <experiment> name for -e.
```
./run.sh -o /home/$USER/isca2024_home -s 4 -e isca
./run.sh -o /home/$USER/isca2024_home -s 5 -e isca.pt
```

The script will launch Scarab simulations background until it run all the different scenarios x workloads. It will take approximately 24 hours. You can check if all the simulations are over by checking if there is any 'scarab' process running (UNIX 'top' command).

## 3. Plot the results
If you don't see any 'scarab' runs, you are now ready to generate the figures.
Run a given script to generate Figure 13, 14, 15, 16, 17 in the paper (Figure13.pdf, Figure14.pdf, ...).

```
cd ./isca2024_udp/plot
./plot_figures.sh
```
