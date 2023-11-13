import csv
import os, sys

# get the stats of interest
def get_acc_stat_from_file(file_name, stat_name, stat_pos):
    with open(file_name, "r") as infile:
        # bug: might not be the only match
        for line in infile:
            splitLine = line.split()
            if stat_name in splitLine:
                val_string = splitLine[stat_pos]
                return int(val_string)

class StatGroup:
    def __init__(self, g_name, s_list):
        self.g_name = g_name
        self.s_list = s_list
        self.weighted_total = 0

class Stat:
    # file name, stat name, stat column number
    def __init__(self, f_name, s_name, pos):
        self.f_name = f_name
        self.s_name = s_name
        self.pos = pos
        self.weighted_average = 0
        self.weighted_ratio = 0

class Simpoint:
    def __init__(self, seg_id, weight, sim_dir):
        self.seg_id = seg_id
        self.weight = weight
        self.sim_dir = sim_dir
        # paralell with stat groups
        # 2-d
        self.stat_vals = []
        self.w_stat_vals = None

def read_simpoints(sp_dir, sim_root_dir):
    total_weight = 0
    simpoints = []
    with open(sp_dir + "opt.p", "r") as f1, open(sp_dir + "opt.w", "r") as f2:
        for line1, line2 in zip(f1, f2):
            seg_id = int(line1.split()[0])
            weight = float(line2.split()[0])
            assert(int(line1.split()[1]) == int(line2.split()[1]))
            total_weight += weight
            simpoints.append(Simpoint(seg_id, weight, sim_root_dir + "/" + str(seg_id)))
    
    if total_weight - 1 > 1e-5:
        print("total weight of SimPoint does not add up to 1? {}".format(total_weight))
        exit
    
    return simpoints

def read_simpoint_stats(stat_groups, simpoints):
    for simp in simpoints:
        for g in stat_groups:
            simp.stat_vals.append([])
            for s in g.s_list:
                stat_val = get_acc_stat_from_file(simp.sim_dir + "/" + s.f_name,
                                                s.s_name, s.pos)
                simp.stat_vals[-1].append(stat_val)

def calculate_weighted_average(stat_groups, simpoints):
    for simp in simpoints:
        simp.w_stat_vals = simp.weight * simp.stat_vals

    for g_id, g in enumerate(stat_groups):
        for s_id, s in enumerate(g.s_list):
            for simp in simpoints:
                s.weighted_average += simp.w_stat_vals[g_id][s_id]

    for g in stat_groups:
        for s in g.s_list:
            g.weighted_total += s.weighted_average

    for g in stat_groups:
        for s in g.s_list:
            s.weighted_ratio = s.weighted_average / g.weighted_total

def report(stat_groups, simpoints, sim_root_dir):
# simps,  weight, stat0 val, stat0 weighted, stat1 val, stat1 weighted,
# simp 0
# simp 1
# simp x
# w avg,    NA  ,  NA      , stat0 w avg   ,  NA  
# w %  ,    NA  ,  NA      , stat1 w rat   ,  NA
    for g_id, g in enumerate(stat_groups):
        with open(sim_root_dir + "/{}.csv".format(g.g_name), "w") as outfile: 
            writer = csv.writer(outfile)

            # title
            # ref: https://stackoverflow.com/questions/11868964/list-comprehension-returning-two-or-more-items-for-each-item
            f1 = lambda x: "{} val".format(x.s_name)
            f2 = lambda x: "{} ratio".format(x.s_name)
            writer.writerow(["Simpoints", "Weight"] + [f(stat) for stat in g.s_list for f in (f1,f2)])

            # middle rows
            for simp in simpoints:
                row = [simp.seg_id, simp.weight]
                for s_id, s in enumerate(g.s_list):
                    row.append(simp.stat_vals[g_id][s_id])
                    row.append(simp.w_stat_vals[g_id][s_id])
                writer.writerow(row)

            writer.writerow([])
            # weighted average
            f1 = lambda x: "NA"
            f2 = lambda x: x.weighted_average
            writer.writerow(["weighted avg", "NA"] + [f(stat) for stat in g.s_list for f in (f1,f2)])

            # weighted ratio
            f1 = lambda x: "NA"
            f2 = lambda x: x.weighted_ratio
            writer.writerow(["weighted %", "NA"] + [f(stat) for stat in g.s_list for f in (f1,f2)])

if __name__ == "__main__":
    if not os.path.isdir(sys.argv[1]):
        print("simpoint directory {} does not exist!")
        exit
    if not os.path.isdir(sys.argv[2]):
        print("simulation directory {} does not exist!")
        exit

    stat_groups = [
        StatGroup("dcache access",
                [
                Stat("memory.stat.0.out", "DCACHE_MISS", 3),
                Stat("memory.stat.0.out", "DCACHE_ST_BUFFER_HIT", 3),
                Stat("memory.stat.0.out", "DCACHE_HIT", 3)
                ]),
        StatGroup("cycles",
                [
                Stat("core.stat.0.out", "NODE_CYCLE", 2)
                ])
    ]

    simpoints = read_simpoints(sys.argv[1], sys.argv[2])
    read_simpoint_stats(stat_groups, simpoints)
    # will calculate Stat.weighted_average, StatGroup.weighted_total, and Stat.weighted_ratio, 
    calculate_weighted_average(stat_groups, simpoints)
    # simpoints.result
    report(stat_groups, simpoints, sys.argv[2])