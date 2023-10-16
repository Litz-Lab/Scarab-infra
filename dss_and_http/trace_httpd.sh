#!/bin/bash

app_cmd="/usr/local/apache2/bin/httpd -C 'ServerName 172.17.0.2:80' -X"
# test_cmd="/usr/local/apache2/bin/ab -n 1 -c 1 http://172.17.0.2:80/"
test_cmd=""
trace_params="-trace_after_instrs 1M -exit_after_tracing 2M -verbose 1"
scarab_params="--frontend memtrace --inst_limit 999900"
collect_traces=" \
cd /home/dcuser/traces \
&& /home/dcuser/scarab/src/deps/dynamorio/build/bin64/drrun \
-t drcachesim -offline -outdir . $trace_params -- $app_cmd $test_cmd \
"
convert_traces=" \
cd /home/dcuser/traces \
&& bash /home/dcuser/scarab/utils/memtrace/run_portabilize_trace.sh \
&& read TRACEDIR < <(ls) \
"
run_scarab=" \
cd /home/dcuser/exp \
&& /home/dcuser/scarab/src/scarab \
--cbp_trace_r0=/home/dcuser/traces/\$TRACEDIR/trace \
--memtrace_modules_log=/home/dcuser/traces/\$TRACEDIR/raw \
$scarab_params \
"
# docker_cmd="$collect_traces && $convert_traces && $run_scarab"
docker_cmd="$collect_traces && $convert_traces"

docker build --no-cache -f httpd/Dockerfile -t httpd -- .
echo \
docker run --name httpd -- httpd bash -c "$docker_cmd"
docker run --name httpd -- httpd bash -c "$docker_cmd"
docker cp httpd:/home/dcuser/traces ./traces
# docker cp httpd:/home/dcuser/exp ./exp
docker container rm httpd
