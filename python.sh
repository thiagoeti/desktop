#!/bin/sh

# pull
docker pull "python:3.9.20-alpine"

# drop
docker rm -f "python"

# run
docker run --name "python" \
	-v "/data":"/data" \
	-w "/data" \
	-it "python":"latest" "/bin/bash"

#
