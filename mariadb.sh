#!/bin/sh

# pull
docker pull "mariadb"

# volume
docker volume create "mariadb"
ln -s "/var/lib/docker/volumes/mariadb" "/data/volume/"

# run
docker run --rm --name "mariadb" \
	-p 3306:3306 \
	-v "mariadb":"/var/lib/mariadb" \
	-e MARIADB_ROOT_PASSWORD="master" \
	-d "mariadb":"latest"

# start
docker start "mariadb"

#
