import argparse

from os import listdir
from os.path import isfile, join

parser = argparse.ArgumentParser(description='Runs scrab on a slurm network')

# Add arguments
parser.add_argument('-p','--path', required=True, help='Path to logs folder')
parser.add_argument('-wl','--workload', required=True, default=False, help='Don\'t launch jobs from descriptor, kill running jobs as described in descriptor')
parser.add_argument('-c','--conf', required=True, default=False, help='Get info about all nodes and if they have containers')
parser.add_argument('-sp','--simpoint', required=True, default=None, help='Launch a docker container on a node. Use ? to pick a random node. Usage: -l bohr1')

# Parse the command-line arguments
args = parser.parse_args()

path = args.path
workload = args.workload
config = args.conf
simpoint = args.simpoint

files = [f for f in listdir(path) if isfile(join(path, f))]

for file in files:
    file_path = join(path, file)
    with open(file_path, "r") as f:
        if f"{config} {workload} {simpoint}" in f.readline():
            print(f"Found in: {file_path}")