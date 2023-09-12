cd /home/memtrace/traces
rm -r `ls -t | awk 'NR>1'`
cd dr*
mkdir -p bin
cp -f raw/modules.log bin/modules.log
cp -f raw/modules.log raw/modules.log.bak
echo "memtrace" | sudo -S python2 /home/memtrace/scarab/utils/memtrace/portabilize_trace.py .
cp -f bin/modules.log raw/modules.log
/home/memtrace/dynamorio/package/build_release-64/clients/bin64/drraw2trace -indir ./raw/
cp -f /home/memtrace/scarab/src/PARAMS.sunny_cove /home/memtrace/exp/PARAMS.in
