#!/bin/bash

# pull
docker pull "phpswoole/swoole:6.0-php8.3-alpine"

# run
docker run --name "swoole" \
	-v "/data":"/data" \
	-w "/data" \
	-p 9502:9502 \
	-e "APP_ENV=development" \
	-e "TZ=America/Sao_Paulo" \
	-it "phpswoole/swoole:6.0-php8.3-alpine" "/bin/sh"

#
