#!/bin/sh

# pull
docker pull "python:latest"

# run
docker run --rm --name "python" \
	-v "/data":"/data" \
	-w "/data" \
	-it "python":"latest" "/bin/bash"

#
