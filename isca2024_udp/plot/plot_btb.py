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
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Times New Roman'] + plt.rcParams['font.serif']

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

def get_IPC(descriptor_data, sim_path):
  benchmarks_org = descriptor_data["workloads_list"].copy()
  benchmarks = []
  ipc_speedup = {}
  mpki = {}
  imiss_cycle = {}

  try:
    for config_key in descriptor_data["configurations"].keys():
      if config_key == "udp_bloom/btb8k/pessimistic_bitmap":
        config_name = "UDP + BTB8K"
        baseline_name = "baseline/32"
      elif config_key == "udp_bloom/btb4k/pessimistic_bitmap":
        config_name = "UDP + BTB4K"
        baseline_name = "baseline/btb4k"
      elif config_key == "udp_bloom/btb16k/pessimistic_bitmap":
        config_name = "UDP + BTB16K"
        baseline_name = "baseline/btb16k"

      ipc_speedups_config = []
      mpki_config = []
      imiss_cycle_config = []
      avg_IPC_speedup_config = 1.0
      avg_MPKI_config = 1
      avg_cyc_imiss_config = 1
      cnt_benchmarks = 0
      for benchmark in benchmarks_org:
        simp,simu,benchmark_name = benchmark.split("/")
        if benchmark_name == "602.gcc_s":
          benchmark_name = "gcc"
        elif benchmark_name == "pt_drupal":
          benchmark_name = "drupal"
        elif benchmark_name == "pt_mediawiki":
          benchmark_name = "mediawiki"
        elif benchmark_name == "pt_tomcat":
          benchmark_name = "tomcat"
        exp_path = sim_path+benchmark+'/'+descriptor_data["experiment"]+'/'
        IPC_baseline = 0
        if simp == 'simpoint_flow':
          df_ipc = pd.read_csv(exp_path+baseline_name+'/ipc.csv')
          IPC_baseline = df_ipc['IPC'][0]
        elif simp == 'nonsimpoint_flow':
          with open(exp_path+baseline_name+'/memory.stat.0.csv') as f:
            lines = f.readlines()
            for line in lines:
              if 'Periodic IPC' in line:
                tokens = [x.strip() for x in line.split(',')]
                IPC_baseline = float(tokens[1])
                break

        cycles = 0
        insts = 0
        IPC = 0
        imiss = 0
        imiss_cyc = 0
        if simp == 'simpoint_flow':
          df_ipc = pd.read_csv(exp_path+config_key+'/ipc.csv')
          df_imiss = pd.read_csv(exp_path+config_key+'/icache_access.csv', index_col='Simpoints')
          df_imiss_cyc = pd.read_csv(exp_path+config_key+'/inst_lost_wait_for_icache_miss.csv', index_col='Simpoints')
          cycles = df_ipc['cycles'][0]
          insts = df_ipc['instructions'][0]
          IPC = df_ipc['IPC'][0]
          imiss = df_imiss['ICACHE_MISS_w_val']['weighted_avg']
          imiss_cyc = df_imiss_cyc['INST_LOST_WAIT_FOR_ICACHE_MISS_w_val']['weighted_avg']
        elif simp == 'nonsimpoint_flow':
          with open(exp_path+config_key+'/memory.stat.0.csv') as f:
            lines = f.readlines()
            for line in lines:
              if 'Periodic Cycles' in line:
                tokens = [x.strip() for x in line.split(',')]
                cycles = float(tokens[1])
                continue
              if 'Periodic Instructions' in line:
                tokens = [x.strip() for x in line.split(',')]
                insts = float(tokens[1])
                continue
              if 'Periodic IPC' in line:
                tokens = [x.strip() for x in line.split(',')]
                IPC = float(tokens[1])
                continue
              if 'ICACHE_MISS_count' in line:
                tokens = [x.strip() for x in line.split(',')]
                imiss = float(tokens[1])
                break

          with open(exp_path+config_key+'/fetch.stat.0.csv') as f:
            lines = f.readlines()
            for line in lines:
              if 'INST_LOST_WAIT_FOR_ICACHE_MISS_count' in line:
                tokens = [x.strip() for x in line.split(',')]
                imiss_cyc = float(tokens[1])
                break

        IPC_speedup = float(IPC)/float(IPC_baseline)
        KI = float(insts)/1000.0
        MPKI = float(imiss)/KI
        cyc_imiss = float(imiss_cyc)/KI
        avg_IPC_speedup_config *= IPC_speedup
        avg_MPKI_config *= MPKI
        avg_cyc_imiss_config *= cyc_imiss

        cnt_benchmarks = cnt_benchmarks + 1
        if len(benchmarks_org) > len(benchmarks):
          benchmarks.append(benchmark_name)

        imiss_cycle_config.append(cyc_imiss)
        ipc_speedups_config.append(100.0*IPC_speedup - 100.0)
        mpki_config.append(MPKI)

      num = len(benchmarks)
      if config_key != baseline_name:
        avg_IPC_speedup_config = avg_IPC_speedup_config**(num**-1)
        ipc_speedups_config.append(100.0*avg_IPC_speedup_config - 100.0)
      mpki_config.append(avg_MPKI_config**(num**-1))
      imiss_cycle_config.append(avg_cyc_imiss_config**(num**-1))

      if config_key != baseline_name:
        ipc_speedup[config_name] = ipc_speedups_config
      mpki[config_name] = mpki_config
      imiss_cycle[config_name] = imiss_cycle_config

    benchmarks.append('Avg')
    plot_data(benchmarks, ipc_speedup, 'IPC Speedup (%)', 'Figure16.pdf')

  except Exception as e:
    print(e)

def plot_data(benchmarks, data, ylabel_name, fig_name, ylim=None):
  print(data)
  colors = ['#800000', '#911eb4', '#4363d8', '#f58231', '#3cb44b', '#46f0f0', '#f032e6', '#bcf60c', '#fabebe', '#e6beff', '#e6194b', '#000075', '#800000', '#9a6324', '#808080', '#ffffff', '#000000']
  ind = np.arange(len(benchmarks))
  width = 0.12
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
  ax.legend(loc="upper left")
  fig.tight_layout()
  plt.savefig(fig_name, format="pdf", bbox_inches="tight")


if __name__ == "__main__":
    # Create a parser for command-line arguments
    parser = argparse.ArgumentParser(description='Read descriptor file name')
    parser.add_argument('-d','--descriptor_name', required=True, help='Experiment descriptor name. Usage: -d exp2.json')
    parser.add_argument('-s','--simulation_path', required=True, help='Simulation result path. Usage: -s /soe/$USER/allbench_home/')

    args = parser.parse_args()
    descriptor_filename = args.descriptor_name

    descriptor_data = read_descriptor_from_json(descriptor_filename)
    get_IPC(descriptor_data, args.simulation_path)
    plt.grid('x')
    plt.tight_layout()
    plt.show()
