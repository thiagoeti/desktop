#!/bin/sh

# pull
docker pull "debian:latest"

# run
docker run --rm --name "debian" \
	-v "/data":"/data" \
	-w "/data" \
	-it "debian":"latest" "/bin/bash"

#
