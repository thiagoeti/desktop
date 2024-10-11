#!/bin/sh

# pull
docker pull "php"

# drop
docker rm -f "php"

# run
docker run --name "php" \
	-v "/data":"/data" \
	-w "/data" \
	-it "php":"latest" "/bin/bash"

#
