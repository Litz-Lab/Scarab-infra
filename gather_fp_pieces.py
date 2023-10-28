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

def append_bbfp(fp_file, chunk_map):
    pairs = []
    for bb_id, bb_freq in chunk_map.items():
        pairs.append(":".join(["", str(bb_id), str(bb_freq)]))
        
    with open(fp_file, "a") as bbfp:
        bbfp.write("T" + " ".join(pairs) + "\n")

def map_conversion(chunk_map, addr_id_map, bb_count):
    new_chunk_map = {}
    for bb_addr, bb_freq in chunk_map.items():
        if not bb_addr in addr_id_map:
            addr_id_map[bb_addr] = bb_count
            bb_count += 1
        new_chunk_map[addr_id_map[bb_addr]] = bb_freq            
    assert len(new_chunk_map) == len(chunk_map)
    return new_chunk_map, addr_id_map, bb_count
    
    
def gather_fp_pieces(fp_dir):
    import glob
    
    pre_chunk_id = -1
    bb_count = 1
    addr_id_map = {}

    # ref: https://stackoverflow.com/questions/4287209/sort-list-of-strings-by-integer-suffix
    for file in sorted(glob.glob(fp_dir + "/chunk.*"), key = lambda x: int(x.split(".")[1])):
        print(file)
        chunk_id = file.split(".")[-1]
        assert int(chunk_id) == pre_chunk_id + 1, "{} != {}".format(chunk_id, pre_chunk_id + 1)
        pre_chunk_id = int(chunk_id)

        with open(file, "r") as f:
            lines = f.read().splitlines()
            if sum(1 for line in lines if line) != 1:
                print("WARN: chunk fp provides more than one line")
            chunk_map = line_to_map(lines[0])

        chunk_map, addr_id_map, bb_count = map_conversion(chunk_map, addr_id_map, bb_count)
        append_bbfp(fp_dir + "/bbfp", chunk_map)

import sys
import os

if __name__ == "__main__":
    if not os.path.isdir(sys.argv[1]):
        print("chunk directory {} does not exist!")
        exit
    gather_fp_pieces(sys.argv[1])
