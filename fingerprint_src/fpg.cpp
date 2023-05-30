#include "dr_api.h"
#include "drmgr.h"
#include "drutil.h"
#include "droption.h"
#include <iostream>
#include <vector>
#include <map>
#include <fstream>
#include <string>
#ifdef WINDOWS
# define DISPLAY_STRING(msg) dr_messagebox(msg)
#else
# define DISPLAY_STRING(msg) dr_printf("%s\n", msg)
#endif

static droption_t<unsigned long long> op_segment_size
(DROPTION_SCOPE_CLIENT, "segment_size", 100000000/*100M*/, "specify the segment size",
 "Specify the size of the segments whose fingerprints will be collected. Default size is 100000000(100M).");

static droption_t<std::string> op_output
(DROPTION_SCOPE_CLIENT, "output", "bbfp", "specify the output file name",
 "Specify the output file name for both SimPoint and csv. Default name is bbfp.");

typedef struct bb_counts {
   uint64 blocks;
   uint64 total_size;
} bb_counts;

typedef struct pc_marker {
   app_pc pc;
   uint64 freq;
    pc_marker(app_pc pc_val, uint64 freq_val) {
        pc = pc_val;
        freq = freq_val;
    }
} pc_marker;

/* Cross-instrumentation-phase data. */
// typedef struct {
//     uint64 bb_id;
// } instru_data_t;

static bb_counts counts_as_built;
void *as_built_lock;
 
static bb_counts counts_dynamic;
void *count_lock;

static uint64 non_fetched_as_built;
static uint64 non_fetched_dynamic;

static uint64 inspect_case_as_built;

static uint64 cur_counter;

static uint64 per_instr_count;
static uint64 per_cur_counter;

// static uint64 segment_size = 10000;
static std::vector<std::map<uint64, uint64> > fingerprints;

static std::map<uint64, std::vector<app_pc> > bb_pc_map;

static std::map<app_pc, uint64> pc_map;
static std::vector<pc_marker> pc_markers;

static bool global_is_emulation = false;

static void
event_exit(void);

static dr_emit_flags_t
event_bb_app2app(void *drcontext, void *tag, instrlist_t *bb, bool for_trace,
                 bool translating);

static dr_emit_flags_t
event_app_analysis(void *drcontext, void *tag, instrlist_t *bb,
                   bool for_trace, bool translating, OUT void **user_data);

static dr_emit_flags_t
event_app_instruction(void *drcontext, void *tag, instrlist_t *bb,
                       instr_t *inst, bool for_trace, bool translating, void *user_data);

static void
clean_call(uint instruction_count, uint64 bb_id, uint64 segment_size, uint non_fetched_count);

DR_EXPORT void
dr_client_main(client_id_t id, int argc, const char *argv[])
{
    std::string parse_err;
    int last_index;
    if (!droption_parser_t::parse_argv(DROPTION_SCOPE_CLIENT, argc, argv, &parse_err, &last_index)) {
        dr_fprintf(STDERR, "Usage error: %s \n at: %d%", parse_err.c_str(), last_index);
        dr_abort();
    }
    // todo: use dr_print() ?
    std::cout << "The segment size: " << op_segment_size.get_value() << std::endl;
    std::cout << "The output name: " << op_output.get_value() << std::endl;

    if (!drmgr_init() || !drutil_init())
        DR_ASSERT(false);

    /* register events */
    dr_register_exit_event(event_exit);
    // dr_register_bb_event(event_basic_block);
    if (!drmgr_register_bb_app2app_event(event_bb_app2app, NULL))
        DR_ASSERT(false);
    if (!drmgr_register_bb_instrumentation_event(event_app_analysis, /*event_app_instruction*/ NULL, NULL))
        DR_ASSERT(false);

    /* initialize lock */
    as_built_lock = dr_mutex_create();
    count_lock = dr_mutex_create();

    // first fingerprint
    // assert(fingerprints.size() == 0);
    std::cout << "initial fps size: " << fingerprints.size() << std::endl;
    fingerprints.push_back(std::map<uint64, uint64>());
}
 
static void
event_exit(void)
{
    /* Display results - we must first snpritnf the string as on windows
     * dr_printf(), dr_messagebox() and dr_fprintf() can't print floats. */
    char msg[512];
    int len;
    len = snprintf(msg, sizeof(msg)/sizeof(msg[0]),
                    "Number of blocks built : %"UINT64_FORMAT_CODE"\n"
                    "     Average size      : %5.2lf instructions\n"
                    "Number of blocks executed  : %"UINT64_FORMAT_CODE"\n"
                    "     Average weighted size : %5.2lf instructions\n"
                    "Number of total instructions : %"UINT64_FORMAT_CODE"\n"
                    "     as-built non-fetched    : %"UINT64_FORMAT_CODE"\n"
                    "     dynamic non-fetched     : %"UINT64_FORMAT_CODE"\n"
                    "Number of total instructions as per: %"UINT64_FORMAT_CODE"\n"
                    "Number of inspect case: %"UINT64_FORMAT_CODE"\n",
                    counts_as_built.blocks,
                    counts_as_built.total_size / (double)counts_as_built.blocks,
                    counts_dynamic.blocks,
                    counts_dynamic.total_size / (double)counts_dynamic.blocks,
                    counts_dynamic.total_size,
                    non_fetched_as_built,
                    non_fetched_dynamic,
                    per_instr_count,
                    inspect_case_as_built);
    DR_ASSERT(len > 0);
    msg[sizeof(msg)/sizeof(msg[0])-1] = '\0';
    DISPLAY_STRING(msg);

    // assert(per_instr_count == counts_dynamic.total_size);

    std::ofstream myfile, mycsv, mymarker;
    myfile.open (op_output.get_value());
    mycsv.open (op_output.get_value() + ".csv");
    mymarker.open(op_output.get_value() + ".mk");
    // T:1540:4   :1541:2

    uint64 total_in_fingerprints = 0;
    bool witness_total = false;

    // WARN: actually if counts_dynamic.total_size % seg size == 0,
    // fingerprints would be one size greater than pc_markers.size()
    // rare but then the implementation would be off
    DR_ASSERT(fingerprints.size() == pc_markers.size());
    for (uint i = 0; i < fingerprints.size(); i++) {
        std::map<uint64, uint64> fp = fingerprints[i];
        myfile << "T";
        std::cout << i << "th fp dimensions: " << fp.size() << std::endl;
        std::map<uint64, uint64>::iterator freq;
        uint64 instrs_count = 0;

        uint64 nonzero_count = 0;
        static std::vector<uint64> csv_line(counts_as_built.blocks, 0);
        for (freq = fp.begin(); freq != fp.end(); freq++) {
            instrs_count += freq->second;
            myfile << ":" << freq->first << ":" << freq->second << " ";

            csv_line[freq->first] = freq->second;
            nonzero_count++;

            if (freq->first + 1 == counts_as_built.blocks) {
                witness_total = true;
            }
        }

        DR_ASSERT(nonzero_count == fp.size());

        std::cout << "num of instrs within segment: " << instrs_count << std::endl << std::flush;
        DR_ASSERT(instrs_count == op_segment_size.get_value() || i == fingerprints.size() - 1);
        total_in_fingerprints += instrs_count;
        myfile << std::endl;

        for (uint j = 0; j < csv_line.size(); j++) {
            mycsv << csv_line[j];
            if (j != csv_line.size() - 1) {
                mycsv << ",";
            }
        }
        mycsv << std::endl;

        mymarker << (void *)pc_markers[i].pc << "," << pc_markers[i].freq << std::endl;
    }
    myfile.close();
    mycsv.close();
    mymarker.close();

    DR_ASSERT(witness_total);
    std::cout << "total within fingerprints: " << total_in_fingerprints << std::endl;
    if (total_in_fingerprints == counts_dynamic.total_size) {
        std::cout << "matched\n";
    } else {
        std::cout << "difffffferent!!!\n";
    }
    /* free mutex */
    dr_mutex_destroy(as_built_lock);
    dr_mutex_destroy(count_lock);
}

static void
clean_call(uint instruction_count, uint64 bb_id, uint64 segment_size, uint non_fetched_count)
{
    dr_mutex_lock(count_lock);

    // increment inst counter
    // increment PC map
    // push the marker
    // the (to_new_vector_count + 1)th pc
    const std::vector<app_pc>& bb_pc = bb_pc_map[bb_id];
    DR_ASSERT(bb_pc.size() == instruction_count);
    for (uint i = 0; i < bb_pc.size(); i++) {
        app_pc cur_pc = bb_pc[i];
        cur_counter++;
        pc_map[cur_pc]++;
        if (cur_counter % segment_size == 1) {
            pc_markers.push_back(pc_marker(cur_pc, pc_map[cur_pc]));
            std::cout<<"marker pushed: " << (void *)cur_pc << ", " << pc_map[cur_pc] << std::endl;
            printf("marker pushed: %ld, %ld\n", cur_pc, pc_map[cur_pc]);
            printf("marker pushed: %ld, %ld\n", (void *)cur_pc, pc_map[cur_pc]);
            printf("marker pushed: %p, %ld\n", cur_pc, pc_map[cur_pc]);
            printf("marker pushed: %p, %ld\n", (void *)cur_pc, pc_map[cur_pc]);
        }
    }

    non_fetched_dynamic += non_fetched_count;

    counts_dynamic.blocks++;
    counts_dynamic.total_size += instruction_count;

    uint to_last_vector_count = 0;
    uint to_new_vector_count = 0;

    // cur_counter += instruction_count;

    // if at a boundary (excluding perfect aligned boundary)
    if (cur_counter > segment_size) {
        to_new_vector_count = cur_counter - segment_size;
        to_last_vector_count = instruction_count - to_new_vector_count;
        // fingerprints.push_back(std::map<uint64, uint64>());
        // std::cout<< "cur fp size: " << fingerprints.size() << std::endl;
    } else {
        to_last_vector_count = instruction_count;
    }

    std::map<uint64, uint64>& fp = fingerprints.back();
    // or just fp[bb_id] += instruction_count;
    if (fp.find(bb_id) == fp.end()) {
        fp.insert(std::make_pair(bb_id, 0));
        std::cout << "new bb detected: " << bb_id << std::endl; 
    }
    // weight each bb by its size
    fp.at(bb_id) += to_last_vector_count;
    // no weight each bb
    // fp.at(bb_id) += 1;

    // it is possible to balance the size by adding offset to the new cur_counter
    // if (cur_counter + instruction_count >= segment_size) {
    //     cur_counter = 0;
    //     fingerprints.push_back(std::map<uint64, uint64>());
    //     std::cout<< "cur fp size: " << fingerprints.size() << std::endl;
    // } else {
    //     cur_counter += instruction_count;
    // }

    // including perfect alignment
    if (cur_counter >= segment_size) {
        fingerprints.push_back(std::map<uint64, uint64>());
        std::cout<< "cur fp size: " << fingerprints.size() << std::endl;
        cur_counter = 0;
        // record the residue
        if (to_new_vector_count > 0) {
            std::map<uint64, uint64>& fp = fingerprints.back();
            fp.insert(std::make_pair(bb_id, to_new_vector_count));
            cur_counter = to_new_vector_count;
        }
    }

    if (cur_counter == 0)
        DR_ASSERT(fingerprints.size() == pc_markers.size() + 1);
    else
        DR_ASSERT(fingerprints.size() == pc_markers.size());
    dr_mutex_unlock(count_lock);
}

static void
clean_call_for_all_instr(/*uint64 bb_id, */uint64 segment_size, app_pc addr)
{
    printf("line: %d\n", __LINE__);

    dr_mutex_lock(count_lock);

    per_instr_count++;
    per_cur_counter++;

    pc_map[addr]++;

    if (per_cur_counter == segment_size) {
        per_cur_counter = 0;
    }

    // if at the start
    if (per_cur_counter == 1) {
        pc_markers.push_back(pc_marker(addr, pc_map[addr]));
        std::cout<< "cur markers size: " << pc_markers.size() << std::endl;
    }

    dr_mutex_unlock(count_lock);
}

/* We transform string loops into regular loops so we can more easily
 * monitor every memory reference they make.
 */
static dr_emit_flags_t
event_bb_app2app(void *drcontext, void *tag, instrlist_t *bb, bool for_trace,
                 bool translating)
{
    /* drbbdup doesn't pass the user_data from this stage so we use TLS.
     * XXX i#5400: Integrating drbbdup into drmgr would provide user_data here.
     */
    if (!drutil_expand_rep_string(drcontext, bb)) {
        DR_ASSERT(false);
        /* in release build, carry on: we'll just miss per-iter refs */
    }
    /*if (!drx_expand_scatter_gather(drcontext, bb, &pt->scatter_gather)) {
        DR_ASSERT(false);
    } */
    return DR_EMIT_DEFAULT;
}

/* samples: inscount and memtrace_x86
 *
 * */
static dr_emit_flags_t
event_app_analysis(void *drcontext, void *tag, instrlist_t *bb,
                  bool for_trace, bool translating, OUT void **user_data)
{
    // dr_printf("bb tag: %p\n", tag);

    uint num_instrs = 0;
    uint local_non_fetched_as_built = 0;
    uint local_inspect_case = 0;
    instr_t *instr;

    uint64 bb_id = 0;

    /* count the number of instructions in this block */
    // for (instr = instrlist_first(bb); instr != NULL; instr = instr_get_next(instr)) {
    //     num_instructions++;
    // }

    bool is_emulation = false;
    uint emulation_length = 0;
    // bb_pc_map[counts_as_built.blocks+1] = std::vector<app_pc>();
    std::vector<app_pc>& bb_pc = bb_pc_map[counts_as_built.blocks+1];
    for (instr = instrlist_first(bb); instr != NULL; instr = instr_get_next(instr)) {
        if (drmgr_is_emulation_start(instr)) {
            /* Each emulated instruction is replaced by a series of native
             * instructions delimited by labels indicating when the emulation
             * sequence begins and ends. It is the responsibility of the
             * emulation client to place the start/stop labels correctly.
             */
            DR_ASSERT(instr == instrlist_first(bb));
            bb_pc.push_back(instr_get_app_pc(instr));
            num_instrs++;
            local_non_fetched_as_built++;
            is_emulation = true;
            /* Data about the emulated instruction can be extracted from the
             * start label using the accessor function:
             * drmgr_get_emulated_instr_data()
             */
            continue;
        }
        if (drmgr_is_emulation_end(instr)) {
            is_emulation = false;
            // std::cout<< "end emulation seq length: " << emulation_length << std::endl;
            continue;
        }
        if (is_emulation) {
            emulation_length++;
            if (instr_get_next(instr) == NULL) {
                std::cout<< "inc emulation till end: " << emulation_length << std::endl;
            }
            continue;
        }
        if (!instr_is_app(instr)) {
            local_inspect_case++;
            continue;
        }
        bb_pc.push_back(instr_get_app_pc(instr));
        num_instrs++;
    }

    DR_ASSERT(num_instrs == bb_pc.size());
    // for (int ii = 0; ii < bb_pc.size(); ii++) {
    //     printf("%ld pc: %ld", counts_as_built.blocks+1, bb_pc[ii]);
    // }
    /* update the as-built counts */
    dr_mutex_lock(as_built_lock);
    inspect_case_as_built += local_inspect_case;
    non_fetched_as_built += local_non_fetched_as_built;
    if (local_non_fetched_as_built) {
        std::cout<< "local_non_fetched_as_built: " <<  local_non_fetched_as_built << std::endl;
        DR_ASSERT(local_non_fetched_as_built == 1);
    }
    // todo: should i start with 0?
    counts_as_built.blocks++;
    counts_as_built.total_size += num_instrs;
    bb_id = counts_as_built.blocks;
    dr_mutex_unlock(as_built_lock);

    std::cout << "woof a bb_id: " << bb_id << std::endl;
 
    /* insert clean call */
    dr_insert_clean_call(drcontext, bb, instrlist_first(bb), (void *)clean_call, false, 4,
                         OPND_CREATE_INT32(num_instrs), OPND_CREATE_INT64(bb_id),
                         OPND_CREATE_INT64(op_segment_size.get_value()),
             OPND_CREATE_INT64(local_non_fetched_as_built));

    return DR_EMIT_DEFAULT;
}

static dr_emit_flags_t
event_app_instruction(void *drcontext, void *tag, instrlist_t *bb,
                       instr_t *inst, bool for_trace, bool translating, void *user_data)
{
    printf("line: %d\n", __LINE__);
    drmgr_disable_auto_predication(drcontext, bb);

    // 1.
    instr_t * real_inst = drmgr_orig_app_instr_for_fetch(drcontext);

    // if (real_inst != NULL) {

    //     dr_insert_clean_call(drcontext, bb, real_inst, (void *)clean_call_for_all_instr,
    //                         false, 2, /*OPND_CREATE_INT64(bb_id),*/
    //                         OPND_CREATE_INT64(op_segment_size.get_value()),
    //                         OPND_CREATE_INTPTR(instr_get_app_pc(real_inst)));
    // }

    // 2.
    // dr_insert_clean_call(drcontext, bb, inst, (void *)clean_call_for_all_instr,
    //                     false, 2, /*OPND_CREATE_INT64(bb_id),*/
    //                     OPND_CREATE_INT64(op_segment_size.get_value()),
    //                     OPND_CREATE_INTPTR(instr_get_app_pc(inst)));

    // 3.
    uint emulation_length = 0;
    if (drmgr_is_emulation_start(inst)) {
        // assert(inst == instrlist_first(bb));
        global_is_emulation = true;
    printf("line: %d\n", __LINE__);

        if (real_inst != NULL) {
            dr_insert_clean_call(drcontext, bb, real_inst, (void *)clean_call_for_all_instr,
                                false, 2, /*OPND_CREATE_INT64(bb_id),*/
                                OPND_CREATE_INT64(op_segment_size.get_value()),
                                OPND_CREATE_INTPTR(instr_get_app_pc(real_inst)));
        }

        // dr_insert_clean_call(drcontext, bb, inst, (void *)clean_call_for_all_instr,
        //                     false, 2, /*OPND_CREATE_INT64(bb_id),*/
        //                     OPND_CREATE_INT64(op_segment_size.get_value()),
        //                     OPND_CREATE_INTPTR(instr_get_app_pc(inst)));
    printf("line: %d\n", __LINE__);

        return DR_EMIT_DEFAULT;
    }
    if (drmgr_is_emulation_end(inst)) {
        global_is_emulation = false;
        // std::cout<< "end emulation seq length: " << emulation_length << std::endl;
    printf("line: %d\n", __LINE__);

        return DR_EMIT_DEFAULT;
    }
    if (global_is_emulation) {
        emulation_length++;
        if (instr_get_next(inst) == NULL) {
            std::cout<< "instrument emulation till end: " << emulation_length << std::endl;
            global_is_emulation = false;
        }
    printf("line: %d\n", __LINE__);

        return DR_EMIT_DEFAULT;
    }
    printf("line: %d\n", __LINE__);

    if (real_inst != NULL) {

        dr_insert_clean_call(drcontext, bb, real_inst, (void *)clean_call_for_all_instr,
                            false, 2, /*OPND_CREATE_INT64(bb_id),*/
                            OPND_CREATE_INT64(op_segment_size.get_value()),
                            OPND_CREATE_INTPTR(instr_get_app_pc(real_inst)));
    }
    // dr_insert_clean_call(drcontext, bb, inst, (void *)clean_call_for_all_instr,
    //                     false, 2, /*OPND_CREATE_INT64(bb_id),*/
    //                     OPND_CREATE_INT64(op_segment_size.get_value()),
    //                     OPND_CREATE_INTPTR(instr_get_app_pc(inst)));
    printf("line: %d\n", __LINE__);

    return DR_EMIT_DEFAULT;
}
