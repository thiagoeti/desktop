#!/bin/sh

# pull
docker pull "alpine"

# drop
docker rm -f "alpine"

# run
docker run --name "alpine" \
	-v "/data":"/data" \
	-w "/data" \
	-it "alpine":"latest" "/bin/sh"

# bash

# apk add bash

#
