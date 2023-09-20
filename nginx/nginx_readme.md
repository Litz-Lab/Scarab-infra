# nginx documentation

## How the benchmark works

Cloudsuite has a 3 container setup for the nginx benchmark (media streaming benchmark: https://github.com/parsa-epfl/cloudsuite/blob/main/docs/benchmarks/media-streaming.md):

The first container runs once to download the dataset and stores it in a volume. The server container will read from this volume to access data. This container and volume must exist for the other two containers to run but the download does not need to occur more than once on the host machine. The script automatically checks to see if the container exists and downloads/starts the container if it does not exist.

The second container runs the server. The image is built from nginx/Dockerfile, nginx/files, and nginx/logs. The script has a new section which starts the server compared to previous applications because nginx (and solr) have to first check for a dataset container and start the server containers with additional volumes. The extra section also runs a command changing the hostname of the container (I could only do it at runtime) to "a" because nginx sometimes complained that the hostname was too long after running on dynamorio. Running the nginx command creates the master process, which then creates a worker process. There is usually more than 1 worker process, but I limit it so we can work with it more easily. It can be changed in line 32 of nginx/Dockerfile at
`RUN sed -i "s/worker_processes auto;/worker_processes 1;/" /etc/nginx/nginx.conf`
Also, there is a way to run nginx as a single process instead of a master process and a worker process. Replace the BINCMD for nginx with:
`BINCMD='nginx -g "daemon off; master_process off; "'`

The third container runs the client. The image is build from nginx/client. The script currently builds the client image every time it is run because it is very fast with docker's caching. I do this because I needed a loop in the entrypoint script that waits to begin execution until the nginx server is up, then sends the signal to stop the nginx server after the client is done. The client parameter takes in several parameters (you can change them at lines 243 and 362), but the last 4 are for configuring the benchmark. The format looks like 
`docker run -dt --name=nginx_client -v /var/run/docker.sock:/var/run/docker.sock -v ./nginx/logs:/videos/logs -v ./nginx/logs:/output --net host nginx_client:latest $(docker exec -it --privileged nginx /bin/bash -c 'hostname -I | cut -d " " -f1 | tr -d "\n"') ${VIDEOPERF_PROCESSES} ${VIDEO_COUNT} ${RATE} ${ENCRYPTION_MODE}`
We use ENCRYPTION_MODE=TLS for realism. The Cloudsuite page has a full explanation for these, but I found that using RATE=100 (with TLS and dynamorio) is the highest rate possible without too many errors or the client quitting too early. I also added another section to the -s option section of the script that handles automating the client container, similarly to how it is done in the -t section.

## How to launch

For memtrace: ./run_scarab.sh -a nginx -o . -p '--inst_limit 10000000' -t -b
-b is required because `APP_GROUPNAME="nginx"` is currently only set under the build flag. Simpoint is not currently working because fingerprinting only targets the first process rather than postprocessing a memtrace.

The -trace_for_instrs flag was not updated with the change in dynamorio version. I found that using -exit_after_tracing in the new version did not work with memtrace, but excluding the flag worked. 

The trace option for run_scarab.sh was not updated with the change in dynamorio version. I replaced the original run_portabilize.sh trace based on what was in run_simpoint.sh. To change this in the future, modify the bottom section of nginx/Dockerfile (lines 41-50) where run_portabilize_trace.sh is overwritten line by line. This is not the cleanest implementation so I have not extended it to the other applications.
Copying PARAMS.sunny_cove to PARAMS.in was also temporarily moved here since I was not sure where else to run it after this change.

Scarab required some new instruction mappings which were added in a pull requests for scarab_hlitz: https://github.com/hlitz/scarab_hlitz/pull/19 (merged)