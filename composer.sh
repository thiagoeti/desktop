#!/bin/bash

# pull
docker pull "composer:latest"

# run
docker run --rm --name "composer" \
	-v "/data":"/data" \
	-w "/data" \
	-p 8000:80 \
	-it "composer:latest" "/bin/bash"

#
