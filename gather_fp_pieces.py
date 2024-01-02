def line_to_map(line):
    line = line.split()
    bb_id_list = []
    freq_list = []
    for pair in line:
        # format :bb_id:freq
        bb_id, freq = pair.split(":")[1:]
        bb_id_list.append(int(bb_id))
        freq_list.append(int(freq))
    fp = {}
    for i,j in zip(bb_id_list, freq_list):
        fp[i] = j
    return fp

def append_bbfp(fp_file, segment_map):
    pairs = []
    for bb_id, bb_freq in segment_map.items():
        pairs.append(":".join(["", str(bb_id), str(bb_freq)]))
        
    with open(fp_file, "a") as bbfp:
        bbfp.write("T" + " ".join(pairs) + "\n")

def map_conversion(segment_map, addr_id_map, bb_count):
    new_segment_map = {}
    for bb_addr, bb_freq in segment_map.items():
        if not bb_addr in addr_id_map:
            addr_id_map[bb_addr] = bb_count
            bb_count += 1
        new_segment_map[addr_id_map[bb_addr]] = bb_freq
    assert len(new_segment_map) == len(segment_map)
    return new_segment_map, addr_id_map, bb_count
    
    
def gather_fp_pieces(fp_dir, num_of_segments):
    import glob
    
    pre_segment_id = -1
    bb_count = 1
    addr_id_map = {}

    # ref: https://stackoverflow.com/questions/4287209/sort-list-of-strings-by-integer-suffix
    for file in sorted(glob.glob(fp_dir + "/segment.*"), key = lambda x: int(x.split(".")[1])):
        print(file)
        segment_id = file.split(".")[-1]
        assert int(segment_id) == pre_segment_id + 1, "{} != {}".format(segment_id, pre_segment_id + 1)
        pre_segment_id = int(segment_id)

        with open(file, "r") as f:
            lines = f.read().splitlines()
            assert sum(1 for line in lines if line) == 1, "segment fp provides more than one line"
            segment_map = line_to_map(lines[0])

        segment_map, addr_id_map, bb_count = map_conversion(segment_map, addr_id_map, bb_count)
        append_bbfp(fp_dir + "/bbfp", segment_map)

    if pre_segment_id + 1 != num_of_segments:
        print("saw {} segments expected {}".format(pre_segment_id + 1, num_of_segments))

import sys
import os

if __name__ == "__main__":
    if not os.path.isdir(sys.argv[1]):
        print("segment directory {} does not exist!")
        exit
    gather_fp_pieces(sys.argv[1], int(sys.argv[2]))
