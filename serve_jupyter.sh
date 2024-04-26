GUIDE_PATH="scarab_stats_quick_start.ipynb"

# Check that guide exists
test -f $GUIDE_PATH
GUIDE_EXISTS=$?

if [[ $GUIDE_EXISTS -ne 0 ]]; then
    echo "ERR: Couldn't find $GUIDE_PATH in the current directory."
    exit 1
fi

# Scan for free ports starting at 8889
BASE_PORT=8889
INCREMENT=1

port=$BASE_PORT
isfree=$(netstat -taln | grep $port)

while [[ -n "$isfree" ]]; do
    port=$[port+INCREMENT]
    isfree=$(netstat -taln | grep $port)
done

echo "Using port: $port"

# Port is now free port

# Launch notebook server quietly as child process on porte
python3 -m notebook --no-browser $GUIDE_PATH --port=$port > /dev/null 2> jupyter_log.txt &
pid=$!

# Create stop program
echo "kill $pid" > stop_jupyter.sh
chmod +x stop_jupyter.sh

# Get username to make ssh tunnel command
me=$(whoami)

# Get the token for the jupyter notebook
sleep 4

IFS="?"

input=$(grep "?token=" jupyter_log.txt)

read -ra array <<< "$input"

token="${array[1]}"

if [[ -z $token ]]; then
    echo "ERR: token empty"
    echo "Got: '$token'"
    echo "sleep before getting token was not long enough"
    echo "OR notebook not installed. Install with pip3 install notebook"
    ./stop_jupyter.sh
    exit 1
fi

echo
echo "Run the following command on your local machine to create a ssh tunnel to the server:"
echo "ssh -NfL localhost:$port:localhost:$port $me@bohr3.soe.ucsc.edu"
echo "(Above not requied if using vscode with Remote - SSH extension)"
echo
echo "Visit the following url in the browser on your local machine to access the notebook:"
echo "http://localhost:$port/notebooks/$GUIDE_PATH?$token"
echo
echo "When you are done run the following on Bohr:"
echo "./stop_jupyter.sh"
echo 
echo "To close the ssh tunnel on your local (unix) machine, use the following to get pid to kill:"
echo "ps -a -o pid,cmd | grep ssh"
echo "(Above not requied if using vscode with Remote - SSH extension)"