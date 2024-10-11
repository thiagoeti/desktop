#!/bin/sh

# pull
docker pull "node"

# drop
docker rm -f "node"

# run
docker run --name "node" \
	-v "/data":"/data" \
	-w "/data" \
	-it "node":"latest" "/bin/bash"

#