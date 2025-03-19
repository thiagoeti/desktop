#!/bin/sh

# pull
docker pull "debian:latest"

# drop
docker rm -f "debian"

# run
docker run --rm --name "debian" \
	-v "/data":"/data" \
	-w "/data" \
	-it "debian":"latest" "/bin/bash"

#
