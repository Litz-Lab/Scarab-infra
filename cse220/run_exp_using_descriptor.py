import json
import argparse
import os
import subprocess

def read_descriptor_from_json(filename="experiment.json"):
    # Read the descriptor data from a JSON file
    try:
        with open(filename, 'r') as json_file:
            descriptor_data = json.load(json_file)
        return descriptor_data
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
        return None
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON in file '{filename}': {e}")
        return None

def run_experiment():
    try:
        # run_exp_using_descriptor.py
        # -d $EXPERIMENT.json
        # -a $APPNAME -g $APP_GROUPNAME : pt_traces
        # -c $BINCMD
        # -m $SCARABMODE &
        # Create a parser for command-line arguments
        parser = argparse.ArgumentParser(description='Read descriptor file name')
        parser.add_argument('-d','--descriptor_name', required=True, help='Experiment descriptor name. Usage: -d exp2.json')
        parser.add_argument('-a','--application_name', required=True, help='Application name. Usage: -a simple_multi_update')
        parser.add_argument('-g','--application_group_name', required=True, help='Application group name. Usage: -g mongodb')
        parser.add_argument('-c','--binary_command', required=False, help='Binary command. Usage -c /usr/bin/mongd --config /etc/mongod.conf')
        parser.add_argument('-m','--scarab_mode', required=True, help='Scarab mode. Usage -m 2')

        # Parse the command-line arguments
        args = parser.parse_args()

        assert args.scarab_mode in ["220"]

        # Specify the filename of the JSON descriptor file
        descriptor_filename = args.descriptor_name

        # Read descriptor data from the JSON file
        descriptor_data = read_descriptor_from_json(descriptor_filename)

        # Check if reading was successful
        if descriptor_data is not None:
            print("Descriptor data read successfully:")
            print(descriptor_data)

        architecture = descriptor_data["architecture"]
        experiment = descriptor_data["experiment"]

        # Run Scarab
        processes = set()
        max_processes = 10
        for workload in descriptor_data["workloads_list"]:
            for config_key in descriptor_data["configurations"].keys():
                exp_path = str(os.getenv('HOME')) + '/exp/simulations/' + workload + '/' + experiment + '/' +config_key
                print(exp_path)
                if os.path.exists(exp_path+'/memory.stat.0.csv'):
                    print(f"The experiment already exists! Change the experiment name.")
                    continue
                config_value = descriptor_data["configurations"][config_key]
                command = 'run_cse220.sh "' + workload + '" "' + args.application_group_name + '" "" "' + experiment + '/' + config_key + '" "' + config_value + '" "' + args.scarab_mode + '" "' + architecture + '"'
                process = subprocess.Popen("exec " + command, stdout=subprocess.PIPE, shell=True)
                processes.add(process)
                while len(processes) >= max_processes:
                    # Loop through the processes and wait for one to finish
                    for p in processes.copy():
                        if p.poll() is not None:  # This process has finished
                            p.wait()  # Make sure it's really finished
                            processes.remove(p)  # Remove from set of active processes
                            break  # Exit the loop after handling one process

        print("Wait processes...")
        for p in processes:
            p.wait()
        print("Simulation done!")

    except KeyboardInterrupt:
        print("Terminating processes...")
        for p in processes:
            p.kill()

if __name__ == "__main__":
    run_experiment()
