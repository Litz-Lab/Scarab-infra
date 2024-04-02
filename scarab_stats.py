import argparse
from typing import List
import pandas as pd
import matplotlib.pyplot as plt
from functools import reduce
import numpy as np

import json
import os
import math

class Experiment:
    def __init__(self, stats):
        '''Stats is either a path to saved experiment or list of stats'''
        if type(stats) == str:
            self.data = pd.read_csv(stats)

        else:
            self.data = pd.DataFrame()
            rows = stats
            rows.append("Experiment")
            rows.append("Architecture")
            rows.append("Configuration")
            rows.append("Workload")
            rows.append("Segment Id")
            rows.append("Cluster Id")
            rows.append("Weight")

            self.data["stats"] = rows

    def add_simpoint(self, simpoint_data, experiment, arch, config, workload, seg_id, c_id, weight):
        column = simpoint_data
        column.append(experiment)
        column.append(arch)
        column.append(config)
        column.append(workload)
        column.append(seg_id)
        column.append(c_id)
        column.append(weight)

        self.data[f"{experiment} {config} {workload} {c_id}"] = column

    def retrieve_stats(self, experiment: str, config: List[str], stats: List[str], workload: List[str], 
                  aggregation_level:str = "Workload", simpoints: List[str] = None):
        results = {}

        if aggregation_level == "Workload":
            for c in config:
                for w in workload:
                    selected_simpoints = [col for col in self.data.columns if f"{experiment} {c} {w}" in col]

                    for stat in stats:
                        values = list(self.data[selected_simpoints][self.data["stats"] == stat].iloc[0])
                        weights = list(self.data[selected_simpoints][self.data["stats"] == "Weight"].iloc[0])
                        values = list(map(float, values))
                        weights = list(map(float, weights))
                        results[f"{c} {w} {stat}"] = sum([v*w for v, w in zip(values, weights)])

        elif aggregation_level == "Simpoint":
            for c in config:
                for w in workload:

                    # Set selected simpoints to all possible if not provided
                    if simpoints == None:
                        selected_simpoints = [col.split(" ")[-1] for col in self.data.columns if f"{experiment} {c} {w}" in col]
                    else: selected_simpoints = simpoints
                    
                    for sp in selected_simpoints:
                        for stat in stats:
                            col = f"{experiment} {c} {w} {sp}"
                            results[f"{c} {w} {sp} {stat}"] = self.data[col][self.data["stats"] == stat].iloc[0]
        
        elif aggregation_level == "Config":
            for c in config:
                config_data = {stat:[] for stat in stats}
                for w in workload:
                    selected_simpoints = [col for col in self.data.columns if f"{experiment} {c} {w}" in col]

                    for stat in stats:
                        values = list(self.data[selected_simpoints][self.data["stats"] == stat].iloc[0])
                        weights = list(self.data[selected_simpoints][self.data["stats"] == "Weight"].iloc[0])
                        values = list(map(float, values))
                        weights = list(map(float, weights))
                        config_data[stat].append(sum([v*w for v, w in zip(values, weights)]))

                #print(config_data)
                for stat, val in config_data.items():
                    results[F"{c} {stat}"] = reduce(lambda x,y: x*y, val) ** (1/len(val))
        
        else:
            print(f"ERROR: Invalid aggreagation level {aggregation_level}.")
            print("Must be 'Workload' 'Simpoint' or 'Config'")
            return None

        return results

    def defragment(self):
        self.data = self.data.copy()

    def derive_stat(self, equation:str):
        # Make sure tokens have space padding
        single_char_tokens = ["+", "-", "*", "/", "(", ")", "="]
        equation = "".join([f" {c} " if c in single_char_tokens else c for c in equation])
        
        # Tokenize
        tokens = list(filter(None, equation.split(" ")))

        total_cols = len(self.data)
        total_setups = len(self.data.iloc[0])

        #self.data.loc[total_cols] = list(self.data.loc[self.data["stats"] == "Weight"])
        
        values = []
        panda_fy = lambda name: f'lookup["{name}"]'

        lookup_cols = {old:new for old, new in zip(self.data.T.columns, self.data.T.iloc[0])}
        str_rows = [list(self.data["stats"]).index(row) for row in ["Experiment","Architecture","Configuration","Workload"]]

        lookup = self.data.T.rename(columns=lookup_cols).drop("stats")
        str_rows = [lookup.columns[i] for i in str_rows]
        lookup = lookup.drop(columns=str_rows).astype("float")

        # TODO: Try transpose and use query with stat names as columns  
        # Just make the stats column the index
        # df.apply()

        # TODO: Make work for rows
        for i, tok in enumerate(tokens):
            if i == 0:
                if tok.isnumeric() or tok in single_char_tokens:
                    print("ERR: Equation should be '<result_name> = ...'")
                    return
                
                tokens[i] = "values.append(list("
                values.append(tok)
                continue

            if i == 1:
                if tok != "=":
                    print("ERR: Equation should be '<result_name> = ...'")
                    return
                tokens[i] = ""

            if not tok.isnumeric() and not tok in single_char_tokens:
                tokens[i] = panda_fy(tok)

            if tok.isnumeric():
                tokens[i] = str(tok)

        tokens.append("))")
        to_eval = " ".join(tokens)

        # TODO: Unsafe!
        eval(to_eval)

        row = [values[0]] + values[1]
        self.data.loc[total_cols] = row
        return
    
    def to_csv(self, path:str):
        '''Turns selected stats from selected workloads/configs into a pandas dataframe'''

        self.data.to_csv(path, index=False)

    def get_experiments(self):
        return list(set(list(self.data[self.data["stats"] == "Experiment"].iloc[0])[2:]))

    def get_configurations(self):
        return list(set(list(self.data[self.data["stats"] == "Configuration"].iloc[0])[2:]))

    def get_workloads(self):
        return list(set(list(self.data[self.data["stats"] == "Workload"].iloc[0])[2:]))

    def get_stats(self):
        return list(set(self.data["stats"]))

    def __repr__(self):
        return str(self)

    def __str__(self):
        return f"{', '.join(list(self.data.columns))}"

# Files for pandas to read, does not like the per line data
stat_files = ["bp.stat.0.csv",
              "core.stat.0.csv",
              "fetch.stat.0.csv",
              "inst.stat.0.csv",
              "l2l1pref.stat.0.csv",
              "memory.stat.0.csv",
              #"per_branch_stats.csv",
              #"per_line_icache_line_info.csv",
              "power.stat.0.csv",
              "pref.stat.0.csv",
              "stream.stat.0.csv"]#,
              #"uop_queue_fill_cycles.csv",
              #"uop_queue_fill_pws.csv",
              #"uop_queue_fill_unique_pws.csv"]

class stat_aggregator:
    def __init__(self) -> None:
        self.experiments = {}
        self.simpoint_info = {}

    def colorwheel(self, x):
        return ((math.cos(2*math.pi*x)+1.5)/2.5, (math.cos(2*math.pi*x+(math.pi/1.5))+1.5)/2.5, (math.cos(2*math.pi*x+2*(math.pi/1.5))+1.5)/2.5)

    def get_all_stats(self, path):
        all_stats = []

        for file in stat_files:
            filename = f"{path}{file}"
            df = pd.read_csv(filename).T
            df.columns = df.iloc[0]
            df = df.drop(df.index[0])
            all_stats += list(df.columns)

        return all_stats
        

    # Load simpoint from csv file as pandas dataframe
    def load_simpoint(self, path):
        data = []
        for file in stat_files:
            filename = f"{path}{file}"
            df = pd.read_csv(filename).T
            df.columns = df.iloc[0]
            df = df.drop(df.index[0])
            data += list(map(float, list(df.iloc[0])))
        return data

    # Load experiment from saved file
    def load_experiment_csv(self, path):
        return Experiment(path)

    # Load experiment form json file, and the corresponding simulations directory
    def load_experiment_json(self, experiment_file: str, simulations_path: str, simpoints_path: str):
        # Load json data from experiment file
        json_data = None
        with open(experiment_file, "r") as file:
            json_data = json.loads(file.read())

        # Make sure simulations and simpoints path has known format
        if simulations_path[-1] != '/': simulations_path += "/"
        if simpoints_path[-1] != '/': simpoints_path += "/"

        experiment_name = json_data["experiment"]
        architecture = json_data["architecture"]

        # Create initial experiment object
        experiment = None

        # Load each configuration
        for config in json_data["configurations"]:

            # Load each workload for each configuration
            for workload in json_data["workloads_list"]:

                # Get path to the simpoint metadata
                metadata_path = f"{simpoints_path}{workload}/simpoints/"
                with open(f"{metadata_path}opt.p.lpt0.99", "r") as cluster_ids, open(f"{metadata_path}opt.w.lpt0.99", "r") as weights:

                    for cluster_id, weight in zip(cluster_ids.readlines(), weights.readlines()):
                        cluster_id, seg_id_1 = [int(i) for i in cluster_id.split()]
                        weight, seg_id_2 = float(weight.split()[0]), int(weight.split()[1])

                        if seg_id_1 != seg_id_2:
                            print(f"ERROR: Simpoints listed out of order in {metadata_path}opt.p.lpt0.99 and opt.w.lpt0.99.")
                            print(f"       Encountered {seg_id_1} in .p and {seg_id_2} in .w")
                            exit(1)

                        directory = f"{simulations_path}{workload}/{experiment_name}/{config}/{str(cluster_id)}/"

                        if experiment == None:
                            all_stats = self.get_all_stats(directory)
                            experiment = Experiment(all_stats)
                        
                        print(f"LOAD {directory}")
                        data = self.load_simpoint(directory)
                        experiment.add_simpoint(data, experiment_name, architecture, config, workload, seg_id_1, cluster_id, weight)
                        print(f"LOADED")
        
        experiment.defragment()
        print("\n\n", experiment)

        return experiment

    # Plot graph comparing different configs
    # Aggregate simpoints
    # Params:
    # experiment file
    # List of stats you are interested in
    # List of configs you are interested in
    # Workloads to plot
    # Baseline config
    # Should plots be each stat individually, or proportion of each stat (Overlayed bar graphs, for percentages that sum to 1)
    # Plot on logarithmic scale

    # Plot multiple stats across multiple workloads
    def plot_workloads (self, experiment: Experiment, experiment_name: str, stats: List[str], workloads: List[str], 
                        configs: List[str], speedup_baseline: str = None, title: str = "Default Title", x_label: str = "", 
                        y_label: str = "", logscale: bool = False, bar_width:float = 0.35, 
                        bar_spacing:float = 0.05, workload_spacing:float = 0.3, average: bool = False, colors = None):
        
        # Get all data with structure all_data[f"{config} {wl} {stat}"]
        configs_to_load = configs + [speedup_baseline]
        all_data = experiment.retrieve_stats(experiment_name, configs_to_load, stats, workloads)

        num_workloads = len(workloads) * len(configs)
        if average: num_workloads += 1
        workload_locations = np.arange(num_workloads) * ((bar_width * len(stats) + bar_spacing * (len(stats) - 1)) + workload_spacing)
        
        plt.figure(figsize=(6,8))

        # For each stat
        for x_offset, stat in enumerate(stats):
            # Plot each workload's stat as bar graph
            data = [all_data[f"{config} {wl} {stat}"] for wl in workloads for config in configs]
            
            if speedup_baseline != None:
                baseline_data = [all_data[f"{speedup_baseline} {wl} {stat}"] for wl in workloads]
                data = [test/baseline for test, baseline in zip(data, baseline_data)]

            if average:
                data.append(reduce(lambda x,y: x*y, data) ** (1/len(data)))

            if colors == None:
                color_map = plt.get_cmap("Paired")
                color = color_map((x_offset*(1/12))%1)
            else:
                color = colors[x_offset%len(colors)]

            b = plt.bar(workload_locations + x_offset*(bar_width + bar_spacing), data, [bar_width] * num_workloads, 
                        color=color)
            b.set_label(stat)
        
        x_ticks = [f"{wl} - {config}" for wl in workloads for config in configs]
        if len(configs) == 1: x_ticks = workloads
        if average: x_ticks.append("Average")
        plt.xticks(workload_locations, x_ticks)

        plt.legend(loc="center left", bbox_to_anchor=(1,0.5))

        if logscale: plt.yscale("log")

        if y_label == "":
            y_label = "Speedup" if speedup_baseline != None else "Count"
        
        plt.title(title)
        plt.xlabel(x_label)
        plt.ylabel(y_label)
        plt.savefig("b.jpeg")

    # Plot multiple stats across simpoints
    def plot_simpoints (self, experiment: Experiment, experiment_name: str, stats: List[str], workloads: List[str], 
                        configs: List[str], simpoints: List[str] = None, speedup_baseline: str = None, 
                        title: str = "Default Title", x_label: str = "", y_label: str = "", 
                        logscale: bool = False, bar_width:float = 0.35, bar_spacing:float = 0.05, workload_spacing:float = 0.3, 
                        average: bool = False, colors = None):
        
        # Get all data with structure all_data[f"{config} {wl} {simpoint} {stat}"]
        configs_to_load = configs + [speedup_baseline]
        all_data = experiment.retrieve_stats(experiment_name, configs_to_load, stats, workloads, aggregation_level="Simpoint", simpoints=simpoints)
        
        plt.figure(figsize=(6,8))

        # For each stat
        for x_offset, stat in enumerate(stats):
            # Plot each workload's stat as bar graph
            data = [val for key, val in all_data.items() if key.split(" ")[-1] == stat and key.split(" ")[0] != speedup_baseline]

            num_workloads = len(data)
            if average: num_workloads += 1
            workload_locations = np.arange(num_workloads) * ((bar_width * len(stats) + bar_spacing * (len(stats) - 1)) + workload_spacing)
            
            if speedup_baseline != None:
                baseline_data = [val for key, val in all_data.items() if key.split(" ")[-1] == stat and key.split(" ")[0] == speedup_baseline]
                if 0 in baseline_data:
                    print("ERR: Found 0 in baseline data. Bar will be set to 0")
                    errors = [key for key, val in all_data.items() if key.split(" ")[-1] == stat and key.split(" ")[0] == speedup_baseline and val == 0]
                    print("Erroneous stat in baseline:", ", ".join(errors))
                    plt.clf()
                    return
                
                data = [test/baseline if baseline != 0 else 0 for test, baseline in zip(data, baseline_data)]

            if average:
                data.append(reduce(lambda x,y: x*y, data) ** (1/len(data)))

            print(workload_locations, data)

            if colors == None:
                color_map = plt.get_cmap("Paired")
                color = color_map((x_offset*(1/12))%1)
            else:
                color = colors[x_offset%len(colors)]

            b = plt.bar(workload_locations + x_offset*(bar_width + bar_spacing), data, [bar_width] * num_workloads, 
                        color=color)
            b.set_label(stat)
        
        if average: workloads.append("Average")

        plt.legend(loc="center left", bbox_to_anchor=(1,0.5))

        if logscale: plt.yscale("log")

        if y_label == "":
            y_label = "Speedup" if speedup_baseline != None else "Count"
        
        plt.title(title)
        plt.xlabel(x_label)
        plt.ylabel(y_label)
        plt.savefig("b.jpeg")

    # Plot multiple stats across simpoints
    def plot_configs (self, experiment: Experiment, experiment_name: str, stats: List[str], workloads: List[str], 
                        configs: List[str], speedup_baseline: str = None, 
                        title: str = "Default Title", x_label: str = "", y_label: str = "", 
                        logscale: bool = False, bar_width:float = 0.35, bar_spacing:float = 0.05, workload_spacing:float = 0.3, 
                        average: bool = False, colors = None):
        
        all_data = experiment.retrieve_stats(experiment_name, configs, stats, workloads, aggregation_level="Config")
        if speedup_baseline != None: baseline_data = experiment.retrieve_stats(experiment_name, [speedup_baseline], stats, workloads, aggregation_level="Config")
        print("Dat", all_data)

        plt.figure(figsize=(6,8))

        # For each stat
        for x_offset, stat in enumerate(stats):
            # Plot each workload's stat as bar graph
            data = [val for key, val in all_data.items() if stat in key]
            num_workloads = len(configs)
            if average: num_workloads += 1
            workload_locations = np.arange(num_workloads) * ((bar_width * len(stats) + bar_spacing * (len(stats) - 1)) + workload_spacing)
            
            if speedup_baseline != None:
                baseline_data = [val for key, val in baseline_data.items() if stat in key]
                if 0 in baseline_data:
                    print("ERR: Found 0 in baseline data. Bar will be set to 0")
                    errors = [key for key, val in all_data.items() if key.split(" ")[-1] == stat and key.split(" ")[0] == speedup_baseline and val == 0]
                    print("Erroneous stat in baseline:", ", ".join(errors))
                    plt.clf()
                    return
                
                data = [test/baseline if baseline != 0 else 0 for test, baseline in zip(data, baseline_data)]

            if average:
                data.append(reduce(lambda x,y: x*y, data) ** (1/len(data)))

            print(workload_locations, data)

            if colors == None:
                color_map = plt.get_cmap("Paired")
                color = color_map((x_offset*(1/12))%1)
            else:
                color = colors[x_offset%len(colors)]

            b = plt.bar(workload_locations + x_offset*(bar_width + bar_spacing), data, [bar_width] * num_workloads, 
                        color=color)
            b.set_label(stat)
        
        if average: workloads.append("Average")

        plt.legend(loc="center left", bbox_to_anchor=(1,0.5))

        if logscale: plt.yscale("log")

        if y_label == "":
            y_label = "Speedup" if speedup_baseline != None else "Count"
        
        plt.title(title)
        plt.xlabel(x_label)
        plt.ylabel(y_label)
        plt.savefig("b.jpeg")


    # Plot simpoints within workload
    # Don't agregate
    # def plot_simpoints (self, experiment, stats, configs, workload)
        

    # Plot stacked bars. List of 
    def plot_stacked (self, experiment: Experiment, experiment_name: str, stats: List[str], workloads: List[str], 
                      configs: List[str], title: str = "Default Title",
                      bar_width:float = 0.35, bar_spacing:float = 0.05, workload_spacing:float = 0.3, colors = None):
        
        # Get all data with structure all_data[stat][config][workload]
        all_data = experiment.retrieve_stats(experiment_name, configs, stats, workloads)
        #all_data = {stat:experiment.get_stat(stat, aggregate = True) for stat in stats}

        num_workloads = len(workloads)
        workload_locations = np.arange(num_workloads) * ((bar_width * len(configs) + bar_spacing * (len(configs) - 1)) + workload_spacing)
        
        plt.figure(figsize=(6,8))

        # For each stat
        for x_offset, config in enumerate(configs):

            offsets = np.array([0.0] * len(workloads))
            totals = {wl: sum([all_data[f"{config} {wl} {stat}"] for stat in stats]) for wl in workloads}

            for i, stat in enumerate(stats):
                # Plot each workload's stat as bar graph
                #data = np.array([all_data[stat][config][wl]/totals[wl] for wl in workloads])
                data = np.array([all_data[f"{config} {wl} {stat}"]/totals[wl] for wl in workloads])

                if colors == None:
                    color_map = plt.get_cmap("Paired")
                    color = color_map((i*(1/12))%1)
                else:
                    color = colors[i%len(colors)]

                b = plt.bar(workload_locations + x_offset*(bar_width + bar_spacing), data, [bar_width] * num_workloads, 
                            bottom=offsets, color = color)
                b.set_label(f"{config} {stat}")
                offsets += data

        plt.title(title)
        plt.ylabel("Fraction of total")
        plt.xlabel("Stat")
        plt.xticks(workload_locations, workloads)
        plt.legend(loc="center left", bbox_to_anchor=(1,0.5))
        plt.savefig("b.jpeg")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument('-d','--descriptor_name', required=True, help='Experiment descriptor name. Usage: -d exp2.json')
    parser.add_argument('-p','--sim_path', required=True, help='Path to the simulation directory. Usage: -p /soe/<USER>/allbench_home/simpoint_flow/simulations/')
    parser.add_argument('-t','--trace_path', required=True, help='Path to the trace directory for reading simpoints. Usage: -t /soe/hlitz/lab/traces/')
    
    args = parser.parse_args()

    da = stat_aggregator()
    #E = da.load_experiment_json(args.descriptor_name, args.sim_path, args.trace_path)
    E = Experiment("panda3.csv")
    #print(E.data)
    #print(E.data)
    #E = Experiment("panda.csv")
    # ipc = instruction / cycles => surrount all column names with df[%s] and then eval()
    #da.plot_stacked(E, "exp2", ['BTB_OFF_PATH_MISS_count', 'BTB_OFF_PATH_HIT_count'], ["mysql", "verilator", "xgboost"], ["fe_ftq_block_num.8", "fe_ftq_block_num.16"])
    #a.plot_workloads(E, "exp2", ["BTB_ON_PATH_MISS_count", "BTB_ON_PATH_HIT_count", "BTB_OFF_PATH_MISS_count", "BTB_ON_PATH_WRITE_count", "BTB_OFF_PATH_WRITE_count"], ["mysql", "verilator", "xgboost"], ["fe_ftq_block_num.8"], speedup_baseline="fe_ftq_block_num.16", logscale=False, average=True)
    #print(E.retrieve_stats("exp2", ["fe_ftq_block_num.16"], ['BTB_OFF_PATH_MISS_count', 'BTB_OFF_PATH_HIT_count'], ["mysql"], "Simpoint"))
    k = 1
    E.derive_stat(f"test=(BTB_OFF_PATH_MISS_count + {k})") 
    da.plot_workloads(E, "exp2", ["test"], ["mysql", "verilator", "xgboost"], ["fe_ftq_block_num.8"], speedup_baseline="fe_ftq_block_num.16", logscale=False, average=True)
    #print(E.get_stats())
    #E.to_csv("test.csv")
    #print(E.retrieve_stats("exp2", ["fe_ftq_block_num.16"], ['BTB_OFF_PATH_MISS_count', 'BTB_OFF_PATH_HIT_count'], ["mysql", "xgboost"], aggregation_level="Config"))
    #da.plot_simpoints(E, "exp2", ["BTB_ON_PATH_MISS_total_count"], ["mysql", "verilator", "xgboost"], ["fe_ftq_block_num.8"], speedup_baseline="fe_ftq_block_num.16", title="Simpoint")
    #da.plot_configs(E, "exp2", ['BTB_OFF_PATH_MISS_count', 'BTB_OFF_PATH_HIT_count'], ["mysql", "xgboost"], ["fe_ftq_block_num.16", "fe_ftq_block_num.8"])
