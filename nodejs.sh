#!/bin/sh

# pull
docker pull "node:latest"

# drop
docker rm -f "node"

# run
docker run --rm --name "node" \
	-v "/data":"/data" \
	-w "/data" \
	-it "node":"latest" "/bin/bash"

#
