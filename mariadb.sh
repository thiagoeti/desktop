#!/bin/sh

# pull
docker pull "mariadb"

# volume
sudo docker volume create "mariadb"
sudo ln -s "/var/lib/docker/volumes/mariadb" "/data/volume/"

# drop
docker rm -f "mariadb"

# run
docker run --name "mariadb" \
	--cpus="4" \
	--memory="8g" \
	-p 3306:3306 \
	-v "/data":"/data" \
	-w "/data" \
	-v "mariadb":"/var/lib/mariadb" \
	-e MARIADB_ROOT_PASSWORD="***" \
	-d "mariadb":"latest"

# start
docker start "mariadb"

#

mariadb --user root --password < /data/tmp/

mariadb database --user root --password --force < /data/tmp/database.sql

#
