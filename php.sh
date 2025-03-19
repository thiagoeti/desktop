#!/bin/sh

# pull
docker pull "php:latest"

# drop
docker rm -f "php"

# run
docker run --rm --name "php" \
	-v "/data":"/data" \
	-w "/data" \
	-it "php":"latest" "/bin/bash"

#
