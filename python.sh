#!/bin/sh

# pull
docker pull "python:latest"

# drop
docker rm -f "python"

# run
docker run --rm --name "python" \
	-v "/data":"/data" \
	-w "/data" \
	-it "python":"latest" "/bin/bash"

#
