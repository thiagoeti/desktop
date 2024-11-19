#!/bin/bash

# pull
docker pull "hyperf/hyperf:8.3-alpine-v3.19-swoole"

# drop
docker rm -f "hyperf"

# run
docker run --name "hyperf" \
	-v "/data":"/data" \
	-w "/data" \
	-p 9501:9501 \
	--privileged -u root \
	--entrypoint /bin/sh \
	-it "hyperf/hyperf:8.3-alpine-v3.19-swoole"

#
