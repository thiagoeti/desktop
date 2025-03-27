#!/bin/sh

# pull
docker pull "php:latest"

# run
docker run --rm --name "php" \
	-v "/data":"/data" \
	-w "/data" \
	-it "php":"latest" "/bin/bash"

#
