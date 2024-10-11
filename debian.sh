#!/bin/sh

# pull
docker pull "debian"

# drop
docker rm -f "debian"

# run
docker run --name "debian" \
	-v "/data":"/data" \
	-w "/data" \
	-it "debian":"latest" "/bin/bash"

#
