#!/bin/sh

# pull
docker pull "alpine:latest"

# drop
docker rm -f "alpine"

# run
docker run --rm --name "alpine" \
	-v "/data":"/data" \
	-w "/data" \
	-it "alpine":"latest" "/bin/sh"

# bash

# apk add bash

#
