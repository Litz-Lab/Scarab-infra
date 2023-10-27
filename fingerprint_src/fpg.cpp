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

using ::dynamorio::droption::DROPTION_SCOPE_CLIENT;
using ::dynamorio::droption::droption_t;

static droption_t<unsigned long long> op_segment_size
(DROPTION_SCOPE_CLIENT, "segment_size", 100000000/*100M*/, "specify the segment size",
 "Specify the size of the segments whose fingerprints will be collected. Default size is 100000000(100M).");

static droption_t<std::string> op_output
(DROPTION_SCOPE_CLIENT, "output", "bbfp", "specify the output file name",
 "Specify the output file name for both SimPoint and csv. Default name is bbfp.");

typedef struct bb_counts {
    uint64 blocks;
    uint64 total_size;
    uint64 non_fetched;
    void clear() {
        blocks = 0;
        total_size = 0;
        non_fetched = 0;
    }
} bb_counts;
// TODO: bb_id and as built blocks are the same?
// TODO: is iterating map producing the correct bb_id order?
typedef struct per_thread_data {
    uint64 bb_id;
    uint64 thread_id;
    bb_counts counts_as_built;
    bb_counts counts_dynamic;
    std::map<uint64, uint64> fingerprints;
    uint64 num_of_segments;
    uint64 cur_counter;

    std::map<app_pc, std::pair<uint64, uint64>> addr_to_bb_for_trace;

    void clear() {
        bb_id = 0;
        thread_id = 0;
        counts_as_built.clear();
        counts_dynamic.clear();
        fingerprints.clear();
        num_of_segments = 0;
        cur_counter = 0;
        addr_to_bb_for_trace.clear();
    }
} per_thread_data;

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

int tls_idx;

void *as_built_lock;
void *count_lock;

static uint64 inspect_case_as_built;

static uint64 per_instr_count;
static uint64 per_cur_counter;

static std::map<uint64, std::vector<app_pc> > bb_pc_map;

static std::map<app_pc, uint64> pc_map;
static std::vector<pc_marker> pc_markers;

static bool global_is_emulation = false;

static void
event_exit(void);
static void
fork_init(void *drcontext);
static void
event_thread_init(void *drcontext);
static void
event_thread_exit(void *drcontext);

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
    using ::dynamorio::droption::droption_parser_t;
    std::string parse_err;
    int last_index;
    if (!droption_parser_t::parse_argv(DROPTION_SCOPE_CLIENT, argc, argv, &parse_err, &last_index)) {
        dr_printf( "Usage error: %s \n at: %d%", parse_err.c_str(), last_index);
        dr_abort();
    }
    dr_printf("The segment size: %lld\n", op_segment_size.get_value());
    dr_printf("The output prefix: %s\n", op_output.get_value().c_str());

    if (!drmgr_init() || !drutil_init())
        DR_ASSERT(false);

    /* register events */
    dr_register_exit_event(event_exit);

    dr_register_fork_init_event(fork_init);

    // will null priority be problematic?
    if (!drmgr_register_thread_init_event(event_thread_init) ||
        !drmgr_register_thread_exit_event_ex(event_thread_exit, NULL))
        DR_ASSERT(false);

    // dr_register_bb_event(event_basic_block);
    if (!drmgr_register_bb_app2app_event(event_bb_app2app, NULL))
        DR_ASSERT(false);
    if (!drmgr_register_bb_instrumentation_event(event_app_analysis, /*event_app_instruction*/ NULL, NULL))
        DR_ASSERT(false);

    /* initialize lock */
    as_built_lock = dr_mutex_create();
    count_lock = dr_mutex_create();

    tls_idx = drmgr_register_tls_field();
}

static void
event_exit(void)
{
    /* Display results - we must first snpritnf the string as on windows
     * dr_printf(), dr_messagebox() and dr_fprintf() can't print floats. */
    char msg[512];
    int len;
    len = snprintf(msg, sizeof(msg)/sizeof(msg[0]),
                    "Number of total instructions as per: %"UINT64_FORMAT_CODE"\n"
                    "Number of inspect case: %"UINT64_FORMAT_CODE"\n",
                    per_instr_count,
                    inspect_case_as_built);
    DR_ASSERT(len > 0);
    msg[sizeof(msg)/sizeof(msg[0])-1] = '\0';
    DISPLAY_STRING(msg);

    // assert(per_instr_count == counts_dynamic.total_size);

    // if (!drmgr_unregister_tls_field(tls_idx) ||
    //     !drmgr_unregister_thread_init_event(event_thread_init) ||
    //     !drmgr_unregister_thread_exit_event(event_thread_exit))
    //     DR_ASSERT(false);

    /* free mutex */
    dr_mutex_destroy(as_built_lock);
    dr_mutex_destroy(count_lock);
}

static void
fork_init(void *drcontext)
{
    // per thread data get copied
    // dunno why that dr_fprintf(STDERR, ) does not work after fork
    per_thread_data *t_data = (per_thread_data *) drmgr_get_tls_field(drcontext, tls_idx);
    t_data->clear();
    t_data->thread_id = dr_get_thread_id(drcontext);
    dr_printf("[%d] fork init\n", t_data->thread_id);
}

static void
event_thread_init(void *drcontext)
{
    /* create an instance of our data structure for this thread */
    per_thread_data *t_data = (per_thread_data *)dr_thread_alloc(drcontext, sizeof(per_thread_data));
    *t_data = {};
    t_data->clear();
    t_data->thread_id = dr_get_thread_id(drcontext);
    dr_printf("[%d] new thread\n", t_data->thread_id);

    /* store it in the slot provided in the drcontext */
    drmgr_set_tls_field(drcontext, tls_idx, t_data);
}

static void
event_thread_exit(void *drcontext)
{
    per_thread_data *t_data = (per_thread_data *) drmgr_get_tls_field(drcontext, tls_idx);
    DR_ASSERT(t_data->thread_id == dr_get_thread_id(drcontext));

    dr_printf("[%d] exit\n", t_data->thread_id);

    /* NOTE - if we so choose we could report per-thread sizes here. */
    /* for now I'll just use lock*/
    // dr_mutex_lock(count_lock);
    // counts_dynamic.blocks += counts->blocks;
    // counts_dynamic.total_size += counts->total_size;
    // dr_mutex_unlock(count_lock);

    // mycsv.open (op_output.get_value() + "." + std::to_string(dr_get_thread_id(drcontext)) + ".csv");
    // mymarker.open(op_output.get_value() + ".mk");
    // T:1540:4   :1541:2

    // bool witness_total = false;

    // WARN: actually if counts_dynamic.total_size % seg size == 0,
    // fingerprints would be one size greater than pc_markers.size()
    // rare but then the implementation would be off
    // DR_ASSERT(fingerprints.size() == pc_markers.size());

    // DR_ASSERT(fingerprints.find(t_data->thread_id) != fingerprints.end());

    std::map<uint64, uint64>& fp = t_data->fingerprints;
    if (fp.size() > 0) {
        t_data->num_of_segments++;

        std::ofstream myfile, mycsv, mymarker;
        myfile.open(op_output.get_value() + "." + std::to_string(dr_get_thread_id(drcontext)), std::ofstream::out | std::ofstream::app);

        if (!myfile.is_open()) {
            dr_printf("open file failed\n");
        }

        myfile << "T";
        std::cout << t_data->num_of_segments << "th fp dimensions: " << fp.size() << std::endl;
        // fine if comment starting here
        std::map<uint64, uint64>::iterator freq;
        uint64 instrs_count = 0;

        uint64 nonzero_count = 0;
        // static std::vector<uint64> csv_line(counts_as_built.blocks, 0);

        for (freq = fp.begin(); freq != fp.end(); freq++) {
            instrs_count += freq->second;
            myfile << ":" << freq->first << ":" << freq->second << " ";

            // csv_line[freq->first] = freq->second;
            nonzero_count++;

            // if (freq->first + 1 == counts_as_built.blocks) {
            //     witness_total = true;
            // }
        }

        DR_ASSERT(nonzero_count == fp.size());

        dr_printf("[%d] exiting, num of instrs within last segment: %lld\n", dr_get_thread_id(drcontext), instrs_count);
        DR_ASSERT(instrs_count == t_data->counts_dynamic.total_size % op_segment_size.get_value());

        myfile << std::endl;

        // for (uint j = 0; j < csv_line.size(); j++) {
        //     mycsv << csv_line[j];
        //     if (j != csv_line.size() - 1) {
        //         mycsv << ",";
        //     }
        // }
        // mycsv << std::endl;

        // mymarker << (void *)pc_markers[i].pc << "," << pc_markers[i].freq << std::endl;

        myfile.close();
    }
    // mycsv.close();
    // mymarker.close();

    // DR_ASSERT(witness_total);

    // snprintf will seg fault?
    dr_printf(
                    "========================================================\n"
                    "Thread: %lld\n"
                    "Number of blocks built : %"UINT64_FORMAT_CODE"\n"
                    "     Average size      : %5.2lf instructions\n"
                    "Number of blocks executed  : %"UINT64_FORMAT_CODE"\n"
                    "     Average weighted size : %5.2lf instructions\n"
                    "Number of total instructions : %"UINT64_FORMAT_CODE"\n"
                    "     as-built non-fetched    : %"UINT64_FORMAT_CODE"\n"
                    "     dynamic non-fetched     : %"UINT64_FORMAT_CODE"\n"
                    // "Number of total instructions as per: %"UINT64_FORMAT_CODE"\n"
                    // "Number of inspect case: %"UINT64_FORMAT_CODE"\n"
                    "========================================================\n"
                    ,
                    t_data->thread_id,
                    t_data->counts_as_built.blocks,
                    t_data->counts_as_built.total_size / (double)t_data->counts_as_built.blocks,
                    t_data->counts_dynamic.blocks,
                    t_data->counts_dynamic.total_size / (double)t_data->counts_dynamic.blocks,
                    t_data->counts_dynamic.total_size,
                    t_data->counts_as_built.non_fetched,
                    t_data->counts_dynamic.non_fetched
                    // ,
                    // per_instr_count,
                    // inspect_case_as_built
                    );

    dr_thread_free(drcontext, t_data, sizeof(per_thread_data));

    dr_printf("[-] exited\n");
}

static void
clean_call(uint instruction_count, uint64 bb_id, uint64 segment_size, uint non_fetched_count)
{
    void *drcontext = dr_get_current_drcontext();
    per_thread_data *t_data = (per_thread_data *) drmgr_get_tls_field(drcontext, tls_idx);
    DR_ASSERT(t_data->thread_id == dr_get_thread_id(drcontext));

    // increment inst counter
    // increment PC map
    // push the marker
    // the (to_new_vector_count + 1)th pc
    // const std::vector<app_pc>& bb_pc = bb_pc_map[bb_id];
    // DR_ASSERT(bb_pc.size() == instruction_count);

    // for (uint i = 0; i < bb_pc.size(); i++) {
        // app_pc cur_pc = bb_pc[i];
        // cur_counter++;
        // pc_map[cur_pc]++;
        // if (cur_counter % segment_size == 1) {
        //     pc_markers.push_back(pc_marker(cur_pc, pc_map[cur_pc]));
        //     std::cout<<"marker pushed: " << (void *)cur_pc << ", " << pc_map[cur_pc] << std::endl;
        //     dr_printf("marker pushed: %ld, %ld\n", cur_pc, pc_map[cur_pc]);
        //     dr_printf("marker pushed: %ld, %ld\n", (void *)cur_pc, pc_map[cur_pc]);
        //     dr_printf("marker pushed: %p, %ld\n", cur_pc, pc_map[cur_pc]);
        //     dr_printf("marker pushed: %p, %ld\n", (void *)cur_pc, pc_map[cur_pc]);
        // }
    // }

    t_data->cur_counter += instruction_count;
    t_data->counts_dynamic.non_fetched += non_fetched_count;
    t_data->counts_dynamic.blocks++;
    t_data->counts_dynamic.total_size += instruction_count;

    uint to_last_vector_count = 0;
    uint to_new_vector_count = 0;

    // if at a boundary (excluding perfect aligned boundary)
    if (t_data->cur_counter > segment_size) {
        to_new_vector_count = t_data->cur_counter - segment_size;
        to_last_vector_count = instruction_count - to_new_vector_count;
    } else {
        to_last_vector_count = instruction_count;
    }

    DR_ASSERT(to_last_vector_count + to_new_vector_count == instruction_count);
    DR_ASSERT((t_data->cur_counter > segment_size) == (to_new_vector_count > 0));

    std::map<uint64, uint64>& fp = t_data->fingerprints;

    // or just fp[bb_id] += instruction_count;
    fp[bb_id] += to_last_vector_count;

    // if (fp.find(bb_id) == fp.end()) {
    //     fp.insert(std::make_pair(bb_id, 0));
    //     // std::cout << "new bb detected: " << bb_id << std::endl;
    //     dr_printf("[%d] detected bb_id %d\n", t_data->thread_id, bb_id);
    // }
    // // weight each bb by its size
    // fp.at(bb_id) += to_last_vector_count;

    // no weight each bb
    // fp.at(bb_id) += 1;

    // including perfect alignment
    if (t_data->cur_counter >= segment_size) {
        t_data->num_of_segments++;
        dr_printf("[%d] to be appened segment num %d\n", t_data->thread_id, t_data->num_of_segments);

        t_data->cur_counter = 0;

        // output the map for this segment
        // make it a function?
        std::ofstream myfile;
        myfile.open(op_output.get_value() + "." + std::to_string(dr_get_thread_id(drcontext)), std::ofstream::out | std::ofstream::app);

        if (!myfile.is_open()) {
            dr_printf("open file failed\n");
        }

        myfile << "T";
        std::cout << t_data->num_of_segments << "th fp dimensions: " << fp.size() << std::endl;
        // fine if comment starting here
        std::map<uint64, uint64>::iterator freq;
        uint64 instrs_count = 0;

        uint64 nonzero_count = 0;
        // static std::vector<uint64> csv_line(counts_as_built.blocks, 0);

        for (freq = fp.begin(); freq != fp.end(); freq++) {
            instrs_count += freq->second;
            myfile << ":" << freq->first << ":" << freq->second << " ";

            // csv_line[freq->first] = freq->second;
            nonzero_count++;

            // if (freq->first + 1 == counts_as_built.blocks) {
            //     witness_total = true;
            // }
        }

        DR_ASSERT(nonzero_count == fp.size());
        DR_ASSERT(instrs_count == op_segment_size.get_value());

        myfile << std::endl;
        myfile.close();

        // clear for the next segment
        fp.clear();

        // record the residue
        if (to_new_vector_count > 0) {
            fp.insert(std::make_pair(bb_id, to_new_vector_count));
            t_data->cur_counter = to_new_vector_count;
        }
    }
    // if (cur_counter == 0)
    //     DR_ASSERT(fingerprints.size() == pc_markers.size() + 1);
    // else
    //     DR_ASSERT(fingerprints.size() == pc_markers.size());
}

static void
clean_call_for_all_instr(/*uint64 bb_id, */uint64 segment_size, app_pc addr)
{
    dr_printf("line: %d\n", __LINE__);

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

/* copied from dynamorio clients/drcachesim/tracer/instru.cpp */
int
count_app_instrs(instrlist_t *ilist, bool for_trace = false)
{
    static int bb_built_count = 0;
    int count = 0;
    bool in_emulation_region = false;
    bool been_in_emulation = false;
    for (instr_t *inst = instrlist_first(ilist); inst != NULL;
         inst = instr_get_next(inst)) {
        if (!in_emulation_region && drmgr_is_emulation_start(inst)) {
            in_emulation_region = true;
            // Each emulation region corresponds to a single app instr.
            ++count;
            // if(!for_trace)
            //     dr_fprintf(STDERR, "[%d]: ad: %p, op: %d\n", bb_built_count, (void *)instr_get_app_pc(inst), instr_get_opcode(inst));
        }
        if (!in_emulation_region && instr_is_app(inst)) {
            // Hooked native functions end up with an artificial jump whose translation
            // is its target.  We do not want to count these.
            if (!(instr_is_ubr(inst) && opnd_is_pc(instr_get_target(inst)) &&
                  opnd_get_pc(instr_get_target(inst)) == instr_get_app_pc(inst))) {
                ++count;
                if (been_in_emulation) {
                    // if(!for_trace)
                    //     dr_fprintf(STDERR, "[ae]");
                }
                // if(!for_trace)
                //     dr_fprintf(STDERR, "[%d]: ad: 0x%p, op: %d\n", bb_built_count, (void *)instr_get_app_pc(inst), instr_get_opcode(inst));

            }
        }
        if (in_emulation_region && drmgr_is_emulation_end(inst)) {
            in_emulation_region = false;
            if(!for_trace)
                been_in_emulation = true;
        }
    }
    if(!for_trace)
        bb_built_count++;
    return count;
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

    per_thread_data *t_data = (per_thread_data *) drmgr_get_tls_field(drcontext, tls_idx);
    // DR_ASSERT(fingerprints.find(t_data->thread_id) != fingerprints.end());
    DR_ASSERT(t_data->thread_id == dr_get_thread_id(drcontext));

    /* count the number of instructions in this block */
    // for (instr = instrlist_first(bb); instr != NULL; instr = instr_get_next(instr)) {
    //     num_instructions++;
    // }

    bool is_emulation = false;
    uint emulation_length = 0;
    // bb_pc_map[counts_as_built.blocks+1] = std::vector<app_pc>();
    // std::vector<app_pc>& bb_pc = bb_pc_map[counts_as_built.blocks+1];
    bool first = true;
    app_pc first_addr;
    for (instr = instrlist_first(bb); instr != NULL; instr = instr_get_next(instr)) {
        if (drmgr_is_emulation_start(instr)) {
            /* Each emulated instruction is replaced by a series of native
             * instructions delimited by labels indicating when the emulation
             * sequence begins and ends. It is the responsibility of the
             * emulation client to place the start/stop labels correctly.
             */
            DR_ASSERT(instr == instrlist_first(bb));
            // bb_pc.push_back(instr_get_app_pc(instr));
            num_instrs++;

            DR_ASSERT(first);
            first = false;
            // instr_t *instr_fetch = drmgr_orig_app_instr_for_fetch(drcontext);
            // DR_ASSERT(instr_fetch);
            first_addr = instr_get_app_pc(instr);
            DR_ASSERT(!first_addr);

            local_non_fetched_as_built++;
            is_emulation = true;
            /* Data about the emulated instruction can be extracted from the
             * start label using the accessor function:
             * drmgr_get_emulated_instr_data()
             */
            continue;
        }
        if (drmgr_is_emulation_end(instr)) {
            DR_ASSERT(instr == instrlist_last(bb));
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
        // bb_pc.push_back(instr_get_app_pc(instr));
        num_instrs++;
        if (first) {
            first = false;
            first_addr = instr_get_app_pc(instr);
        }
    }

    int compare_count = count_app_instrs(bb, for_trace);

    // DR_ASSERT(num_instrs == bb_pc.size());
    // for (int ii = 0; ii < bb_pc.size(); ii++) {
    //     dr_printf("%ld pc: %ld", counts_as_built.blocks+1, bb_pc[ii]);
    // }
    /* update the as-built counts */
    dr_mutex_lock(as_built_lock);
    if (!for_trace) {
        inspect_case_as_built += local_inspect_case;
    }
    if (local_non_fetched_as_built) {
        std::cout<< "local_non_fetched_as_built: " <<  local_non_fetched_as_built << std::endl;
        DR_ASSERT(local_non_fetched_as_built == 1);
    }
    dr_mutex_unlock(as_built_lock);

    // thread private no need lock
    uint64 cleancall_bb_id;
    if (!for_trace) {
        t_data->counts_as_built.non_fetched += local_non_fetched_as_built;
        t_data->counts_as_built.blocks++;
        t_data->counts_as_built.total_size += num_instrs;

        t_data->bb_id++;
        dr_printf("[%d] a new bb_id %d\n", dr_get_thread_id(drcontext), t_data->bb_id);

        if (t_data->addr_to_bb_for_trace.find(first_addr) != t_data->addr_to_bb_for_trace.end()) {
            dr_printf("??existed first addr %p, bb_id %lu, count %lu\n", first_addr, t_data->addr_to_bb_for_trace[first_addr].first, t_data->addr_to_bb_for_trace[first_addr].second);
            dr_printf("??new first addr %p, count %lu\n", first_addr, num_instrs);
        }

        DR_ASSERT(t_data->addr_to_bb_for_trace.find(first_addr) == t_data->addr_to_bb_for_trace.end() || (num_instrs == 1 && first_addr == 0));
        // t_data->addr_to_bb_for_trace.insert(std::make_pair(first_addr, std::make_pair(t_data->bb_id, num_instrs)));
        t_data->addr_to_bb_for_trace[first_addr] = std::make_pair(t_data->bb_id, num_instrs);
        if (!first_addr) {
            dr_printf("??zero emulation addr %p, bb_id %lu, count %lu\n", first_addr, t_data->addr_to_bb_for_trace[first_addr].first, t_data->addr_to_bb_for_trace[first_addr].second);
        }

        cleancall_bb_id = t_data->bb_id;
    } else {
        // get the bb id for the bb in trace
        DR_ASSERT(t_data->addr_to_bb_for_trace.find(first_addr) != t_data->addr_to_bb_for_trace.end());
        cleancall_bb_id = t_data->addr_to_bb_for_trace[first_addr].first;
        if (num_instrs != t_data->addr_to_bb_for_trace[first_addr].second) {
            dr_printf("[%d] bb_id %d has different inst count %lu %lu from trace\n", dr_get_thread_id(drcontext), cleancall_bb_id, num_instrs, t_data->addr_to_bb_for_trace[first_addr].second);
        }
    }

    if (compare_count != num_instrs) {
        dr_printf("[%d] bb_id %d has different inst count %d %lu from function\n", dr_get_thread_id(drcontext), cleancall_bb_id, compare_count, num_instrs);
    }

    /* insert clean call */
    dr_insert_clean_call(drcontext, bb, instrlist_first(bb), (void *)clean_call, false, 4,
                        OPND_CREATE_INT32(num_instrs), OPND_CREATE_INT64(cleancall_bb_id),
                        OPND_CREATE_INT64(op_segment_size.get_value()),
                        OPND_CREATE_INT32(local_non_fetched_as_built));

    return DR_EMIT_DEFAULT;
}

static dr_emit_flags_t
event_app_instruction(void *drcontext, void *tag, instrlist_t *bb,
                       instr_t *inst, bool for_trace, bool translating, void *user_data)
{
    dr_printf("line: %d\n", __LINE__);
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
    dr_printf("line: %d\n", __LINE__);

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
    dr_printf("line: %d\n", __LINE__);

        return DR_EMIT_DEFAULT;
    }
    if (drmgr_is_emulation_end(inst)) {
        global_is_emulation = false;
        // std::cout<< "end emulation seq length: " << emulation_length << std::endl;
    dr_printf("line: %d\n", __LINE__);

        return DR_EMIT_DEFAULT;
    }
    if (global_is_emulation) {
        emulation_length++;
        if (instr_get_next(inst) == NULL) {
            std::cout<< "instrument emulation till end: " << emulation_length << std::endl;
            global_is_emulation = false;
        }
    dr_printf("line: %d\n", __LINE__);

        return DR_EMIT_DEFAULT;
    }
    dr_printf("line: %d\n", __LINE__);

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
    dr_printf("line: %d\n", __LINE__);

    return DR_EMIT_DEFAULT;
}
