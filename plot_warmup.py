import gather_cluster_results
import subprocess
from time import sleep
import shutil
# pip install plotly==5.18.0
import plotly.graph_objects as go

# ref: https://stackoverflow.com/a/13197763
class cd:
    """Context manager for changing the current working directory"""
    def __init__(self, newPath):
        self.newPath = os.path.expanduser(newPath)

    def __enter__(self):
        self.savedPath = os.getcwd()
        os.chdir(self.newPath)

    def __exit__(self, etype, value, traceback):
        os.chdir(self.savedPath)

def get_top_simpoint(simpoints):
    max_weight = 0
    max_index = 0
    for simp_i, simp in enumerate(simpoints):
        if simp.weight > max_weight:
            max_weight = simp.weight
            max_index = simp_i
    
    return simpoints[max_index]

# ub: upper bound in M
def run_vary_warmup_legth(SCARABHOME, MODULESDIR, TRACEFILE, OUTDIR, segID, SEGSIZE, ub):
    p_list = []
    warmup_unit = 1000000
    seg_root = OUTDIR + "/" + str(segID)
    os.makedirs(seg_root, exist_ok=True)
    for WARMUP in range(ub+1):
        warmup_dir = seg_root + "/" + str(WARMUP)
        os.makedirs(warmup_dir)
        
        # convert to actual instruction number
        WARMUP = WARMUP * warmup_unit
        with cd(warmup_dir):
            shutil.copyfile(SCARABHOME +"/src/PARAMS.sunny_cove",
                            warmup_dir + "/PARAMS.in")

            roiStart = segID * SEGSIZE + 1
            roiEnd = segID * SEGSIZE + SEGSIZE

            if roiStart > WARMUP:
                roiStart = roiStart - WARMUP
            else:
                # no enough preceding instructions, can only warmup till segment start
                WARMUP = roiStart - 1
                # new roi start is the very first instruction of the trace
                roiStart = 1

            instLimit = roiEnd - roiStart + 1

            scarabCmd="$SCARABHOME/src/scarab \
            --frontend memtrace \
            --cbp_trace_r0=$TRACEFILE \
            --memtrace_modules_log=$MODULESDIR \
            --memtrace_roi_begin=$roiStart \
            --memtrace_roi_end=$roiEnd \
            --inst_limit=$instLimit \
            --full_warmup=$WARMUP \
            $SCARABPARAMS \
            &> sim.log"

            executable = SCARABHOME + "/src/scarab"
            scarab_cmd = [executable,
                        "--frontend", "memtrace",
                        "--cbp_trace_r0", TRACEFILE,
                        "--memtrace_modules_log", MODULESDIR,
                        "--memtrace_roi_begin", roiStart,
                        "--memtrace_roi_end", roiEnd,
                        "--inst_limit", str(instLimit),
                        "--full_warmup", WARMUP
                        ]
            # log file at cur dir
            log_file = "./sim.log"
            print(scarab_cmd, flush=True)
            with open(log_file, "w") as outfile:
                p_list.append(subprocess.Popen(scarab_cmd, stdout=outfile, shell=False))
            while True:
                live = 0
                for p in p_list:
                    if p.poll() is None:
                        live += 1
                if live < 40:
                    break
                else:
                    sleep(300)

    print("wait for all warm-up runs to finish...")
    for p in run_warmup_tests_for_bench_p_list:
        p.wait()

def plot(OUTDIR, segID, ub):
    seg_root = OUTDIR + "/" + str(segID)
    warmup_dir_list = [seg_root + "/" + str(WARMUP) for WARMUP in range(ub+1)]

    for g in stat_groups:
        fig = go.Figure()
        for s in g.s_list:
            y_vals=[get_acc_stat_from_file(warmup_dir + "/" + g.f_name, s.s_name, s.pos) for warmup_dir in warmup_dir_list]
            fig.add_trace(
                go.Scatter(
                    x=[ins.warm_length for ins in case_list],
                    y=y_vals,
                    name=s.s_name,
                    visible='legendonly'
                )
            )
        fig.update_layout(
            title = g.g_name
        )
        with open("{}/warmup.html".format(OUTDIR), 'a') as f:
            f.write(fig.to_html(full_html=False, include_plotlyjs="cdn"))

if __name__ == "__main__":
    if not os.path.isdir(sys.argv[1]):
        print("simpoint directory {} does not exist!")
        exit
    if not os.path.isdir(sys.argv[2]):
        print("simulation directory {} does not exist!")
        exit

    simpoints = read_simpoints(sys.argv[1], "not applicable")
    top_simpoint = get_top_simpoint(simpoints)
    run_vary_warmup_legth(sys.argv[2], top_simpoint.seg_id, 300)
    plot(sys.argv[2] + "/" + str(top_simpoint.seg_id))