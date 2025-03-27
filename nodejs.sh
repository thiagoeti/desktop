#!/bin/sh

# pull
docker pull "node:latest"

# run
docker run --rm --name "node" \
	-v "/data":"/data" \
	-w "/data" \
	-it "node":"latest" "/bin/bash"

#
