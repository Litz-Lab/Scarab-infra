import os
import json
import argparse
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import csv
from matplotlib import cm

matplotlib.rc('font', size=14)

def read_descriptor_from_json(descriptor_filename):
    # Read the descriptor data from a JSON file
    try:
        with open(descriptor_filename, 'r') as json_file:
            descriptor_data = json.load(json_file)
        return descriptor_data
    except FileNotFoundError:
        print(f"Error: File '{descriptor_filename}' not found.")
        return None
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON in file '{descriptor_filename}': {e}")
        return None

def get_IPC(descriptor_data, sim_path, output_dir):
  benchmarks_org = descriptor_data["workloads_list"].copy()
  benchmarks = []
  ipc = {}

  try:
    for config_key in descriptor_data["configurations"].keys():
      ipc_config = []
      avg_IPC_config = 0.0
      cnt_benchmarks = 0
      for benchmark in benchmarks_org:
        benchmark_name = benchmark.split("/")
        exp_path = sim_path+'/'+benchmark+'/'+descriptor_data["experiment"]+'/'
        IPC = 0
        with open(exp_path+config_key+'/memory.stat.0.csv') as f:
          lines = f.readlines()
          for line in lines:
            if 'Periodic IPC' in line:
              tokens = [x.strip() for x in line.split(',')]
              IPC = float(tokens[1])
              break

        avg_IPC_config += IPC

        cnt_benchmarks = cnt_benchmarks + 1
        if len(benchmarks_org) > len(benchmarks):
          benchmarks.append(benchmark_name)

        ipc_config.append(IPC)

      num = len(benchmarks)
      print(benchmarks)
      ipc_config.append(avg_IPC_config/num)
      ipc[config_key] = ipc_config

    benchmarks.append('Avg')
    plot_data(benchmarks, ipc, 'IPC', output_dir+'/FigureA.png')

  except Exception as e:
    print(e)

def plot_data(benchmarks, data, ylabel_name, fig_name, ylim=None):
  print(data)
  colors = ['#800000', '#911eb4', '#4363d8', '#f58231', '#3cb44b', '#46f0f0', '#f032e6', '#bcf60c', '#fabebe', '#e6beff', '#e6194b', '#000075', '#800000', '#9a6324', '#808080', '#ffffff', '#000000']
  ind = np.arange(len(benchmarks))
  width = 0.18
  fig, ax = plt.subplots(figsize=(14, 4.4), dpi=80)
  num_keys = len(data.keys())

  idx = 0
  start_id = -int(num_keys/2)
  for key in data.keys():
    hatch=''
    if idx % 2:
      hatch='\\\\'
    else:
      hatch='///'
    ax.bar(ind + (start_id+idx)*width, data[key], width=width, fill=False, hatch=hatch, color=colors[idx], edgecolor=colors[idx], label=key)
    idx += 1
  ax.set_xlabel("Benchmarks")
  ax.set_ylabel(ylabel_name)
  ax.set_xticks(ind)
  ax.set_xticklabels(benchmarks, rotation = 27, ha='right')
  ax.grid('x');
  if ylim != None:
    ax.set_ylim(ylim)
  ax.legend(loc="upper left", ncols=2)
  fig.tight_layout()
  plt.savefig(fig_name, format="png", bbox_inches="tight")


if __name__ == "__main__":
    # Create a parser for command-line arguments
    parser = argparse.ArgumentParser(description='Read descriptor file name')
    parser.add_argument('-o','--output_dir', required=True, help='Output path. Usage: -o /home/$USER/plot')
    parser.add_argument('-d','--descriptor_name', required=True, help='Experiment descriptor name. Usage: -d /home/$USER/lab1.json')
    parser.add_argument('-s','--simulation_path', required=True, help='Simulation result path. Usage: -s /home/$USER/exp/simulations')

    args = parser.parse_args()
    descriptor_filename = args.descriptor_name

    descriptor_data = read_descriptor_from_json(descriptor_filename)
    get_IPC(descriptor_data, args.simulation_path, args.output_dir)
    plt.grid('x')
    plt.tight_layout()
    plt.show()
