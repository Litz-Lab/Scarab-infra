# How to use
To use the python scarab stats api, you first need to run an experiment file on scarab. 
You will need the path to the experiment json file, the path to the simulations, and the path to the traces used
The trace path is usually /soe/hlitz/lab/traces on bohr3

The stats api is best used in a jupyter notebook. Any notebook that can be ran on the same machine as the simulations works.
I use vscode with the jupyter extention and the Remote - SSH extention to get a notebook running on bohr3

## Quickstart
To use it, first import the library using
`import scarab_stats`

Then create a `stat_aggregator` to load an experiment from the stat files produces by scarab
`aggregator = scarab_stats.stat_aggregator()`

And finally load your experiment using the `load_experiment_json` function. It requires a path to the experiment file, a path to the simulations directory, and a parth to the traces dierectory
Ex:
`experiment = aggregator.load_experiment_json("allbench_home/exp2.json", "allbench_home/simpoint_flow/simulations", "/soe/hlitz/lab/traces/")`

NOTE: There is a bug where the representation of a freshly loaded experiment is different from a saved one. Please use `experiment.to_csv(path)` on the resulting experiment and then reload with `experiment = Experiment(path)`

Then you can use any of the `stat_aggregator` class's plotting functions, or retreive data directly from the experiment

## Documentation
### stat_aggregator
#### load_experiment_json
Arguments: (experiment_file: str, simulations_path: str, simpoints_path: str)

NOTE: There is a bug where the representation of a freshly loaded experiment is different from a saved one. Please use `experiment.to_csv(path)` on the resulting experiment and then reload with `experiment = Experiment(path)`

This function returns an experiment object loaded from the path provided. 

- experiment_file: the json file used to run the experiment containing all the data about it
- simulations_path: the path to the simulations directory created by scarab
- simpoints_path: the path to the traces that contain information about all the simpoints (/soe/hlitz/lab/traces/)

#### load_experiment_csv
Arguments: (path: str)

Loads an experiment from a csv file. Equivalent to `Experiment(path)`

- path: Path to the csv file of the experiment

#### plot_workloads 
Arguments: (experiment: Experiment, experiment_name: str, stats: List[str], workloads: List[str], 
            configs: List[str], speedup_baseline: str = None, title: str = "Default Title", x_label: str = "", 
            y_label: str = "", logscale: bool = False, bar_width:float = 0.35, 
            bar_spacing:float = 0.05, workload_spacing:float = 0.3, average: bool = False, colors = None)

Generates a plot of all requested statistics aggregating stats across all simpoints for each workload. Can plot multiple workloads at once

- Experiment: The experiment object to be used
- experiment_name: The string name of the experiment, from the json file
- stats: A list of the names of all the desired stats to be plotted
- workloads: A list of the names of all workloads from the experiment to be plotted
- configs: A list of all the configs from the experiment to be plotted (minus the baseline, if desired)
- THE FOLLOWING ARE OPTIONAL
- speedup_baseline: If calculating speedups over a baseline config is desired put the name of the baseline config here
- title: The title of the plot
- x_label: The label of the x axis of the plot
- y_label: The label of the y axis of the plot. Default is Count or Speedup depending on if baseline provided
- logscale: Set y axis to logorithmic scaling
- bar_width: The width of bars for statistics
- bar_spacing: The size of the space between stat bars
- workload_spacing: The additional spacing added to differentiate stats of different workloads
- average: Add an extra group of the averages of all the stats
- colors: A list of colors for each different stat. Chosen dynamically if not set

#### plot_simpoints
Arguments: (experiment: Experiment, experiment_name: str, stats: List[str], workloads: List[str], 
            configs: List[str], simpoints: List[str] = None, speedup_baseline: str = None, 
            title: str = "Default Title", x_label: str = "", y_label: str = "", 
            logscale: bool = False, bar_width:float = 0.35, bar_spacing:float = 0.05, workload_spacing:float = 0.3, 
            average: bool = False, colors = None):

Generates a plot of all requested statistics, does NOT aggregate stats across each workload. Can plot multiple workloads and configs at once

- Experiment: The experiment object to be used
- experiment_name: The string name of the experiment, from the json file
- stats: A list of the names of all the desired stats to be plotted
- workloads: A list of the names of all workloads from the experiment to be plotted
- configs: A list of all the configs from the experiment to be plotted (minus the baseline, if desired)
- THE FOLLOWING ARE OPTIONAL
- simpoints: Select specific simpoints to plot, and ignore rest. Default option plots all
- speedup_baseline: If calculating speedups over a baseline config is desired put the name of the baseline config here
- title: The title of the plot
- x_label: The label of the x axis of the plot
- y_label: The label of the y axis of the plot. Default is Count or Speedup depending on if baseline provided
- logscale: Set y axis to logorithmic scaling
- bar_width: The width of bars for statistics
- bar_spacing: The size of the space between stat bars
- workload_spacing: The additional spacing added to differentiate stats of different workloads
- average: Add an extra group of the averages of all the stats
- colors: A list of colors for each different stat. Chosen dynamically if not set

#### plot_configs
Arguments: (experiment: Experiment, experiment_name: str, stats: List[str], workloads: List[str], 
            configs: List[str], speedup_baseline: str = None, 
            title: str = "Default Title", x_label: str = "", y_label: str = "", 
            logscale: bool = False, bar_width:float = 0.35, bar_spacing:float = 0.05, workload_spacing:float = 0.3, 
            average: bool = False, colors = None)

Generates a plot of all requested configs aggregating across workloads (with even weighting). Can plot multiple configs at once

- Experiment: The experiment object to be used
- experiment_name: The string name of the experiment, from the json file
- stats: A list of the names of all the desired stats to be plotted
- workloads: A list of the names of all workloads from the experiment to be plotted
- configs: A list of all the configs from the experiment to be plotted (minus the baseline, if desired)
- THE FOLLOWING ARE OPTIONAL
- speedup_baseline: If calculating speedups over a baseline config is desired put the name of the baseline config here
- title: The title of the plot
- x_label: The label of the x axis of the plot
- y_label: The label of the y axis of the plot. Default is Count or Speedup depending on if baseline provided
- logscale: Set y axis to logorithmic scaling
- bar_width: The width of bars for statistics
- bar_spacing: The size of the space between stat bars
- workload_spacing: The additional spacing added to differentiate stats of different workloads
- average: Add an extra group of the averages of all the stats
- colors: A list of colors for each different stat. Chosen dynamically if not set

#### plot_stacked
Arguments: (experiment: Experiment, experiment_name: str, stats: List[str], workloads: List[str], 
            configs: List[str], title: str = "Default Title", 
            bar_width:float = 0.35, bar_spacing:float = 0.05, workload_spacing:float = 0.3, colors = None)

Generates a plot where the requested statistics are stacked into one bar to see the ratios between them. An example would be plotting 'BTB_OFF_PATH_MISS_count' and 'BTB_OFF_PATH_HIT_count' to show the ratio of hits and misses of the BTB when off path. Can only do one set of stats per graph right now, but can plot across multiple workloads and configs.

- Experiment: The experiment object to be used
- experiment_name: The string name of the experiment, from the json file
- stats: A list of the names of all the desired stats to be plotted
- workloads: A list of the names of all workloads from the experiment to be plotted
- configs: A list of all the configs from the experiment to be plotted (minus the baseline, if desired)
- THE FOLLOWING ARE OPTIONAL
- title: The title of the plot
- bar_width: The width of bars for statistics
- bar_spacing: The size of the space between stat bars
- workload_spacing: The additional spacing added to differentiate stats of different workloads
- colors: A list of colors for each different stat. Chosen dynamically if not set

### Experiment
The experiment class is used to store all the data about an experiment, containing all stats

#### Constructor
Arguments: (path: str)

Using Experiment(path) will automatically load an experiment from a saved csv file

- path: path of saved file

#### get_stats
Arguments: (experiment: str, config: List[str], stats: List[str], workload: List[str], 
            aggregation_level:str = "Workload", simpoints: List[str] = None)

Gets statistics as a dictionary format is different depending on agregation level. Each one can be accessed as follows:
aggregation_level = "Workload": f"{config} {workload} {statistic}"
aggregation_level = "Simpoint": f"{config} {workload} {simpoint} {statistic}"
aggregation_level = "Config": f"{config} {statistic}"

- experiment: The name of the experiment you want data from
- config: A list of the configurations you want data from
- workload: A list of workloads you want data from
- THE FOLLOWING ARE NOT REQUIRED
- aggregation_level: The level that stats should be agregated to. "Workload" "Simpoint" or "Config"
- simpoints: For aggregation level "Simpoint", optionally provide which simpoints you want data from. Default is all

#### derive_stat
Arguments: (equation:str)

Creates a new stat column using the given equation. Format should be similar to `new_stat_name = stat_name + stat_name_2 * 42`. Format strings can be used to insert variables

- equation: The equation to be used to derive a new statistic. + - * / all work, with column names or number literals.

#### to_csv
Arguments: (path: str)

Saves experiment as csv file

- path: The path for the csv file to be generated

#### get_experiments
Arguments: None

Returns a set of all the names of all the experiments contained in the experiment object

#### get_configurations
Arguments: None

Returns a set of all the names of all the configurations contained in the experiment object

#### get_workloads
Arguments: None

Returns a set of all the names of all the workloads contained in the experiment object