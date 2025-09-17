#!/bin/sh

# pull
docker pull "mysql:5.7.44"

# volume
docker volume create "mysql_old"
ln -s "/var/lib/docker/volumes/mysql_old" "/data/volume/"

# run
docker run --rm --name "mysql_old" \
	-p 3306:3306 \
	-v "mysql_old":"/var/lib/mysql" \
	-e MYSQL_ROOT_PASSWORD="***" \
	-d mysql:5.7.44

# start
docker start "mysql_old"

#
