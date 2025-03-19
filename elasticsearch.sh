#!/bin/sh

# pull
docker pull "docker.elastic.co/elasticsearch/elasticsearch:8.17.2"

# volume
docker volume create "elasticsearch"
ln -s "/var/lib/docker/volumes/elasticsearch" "/data/volume/"

# run
docker run --rm --name elasticsearch \
	-p 9200:9200 \
	-p 9300:9300 \
	-e "discovery.type=single-node" \
	-e "xpack.security.enabled=false" \
	-e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
	-v elasticsearch:/usr/share/elasticsearch/data \
	-d docker.elastic.co/elasticsearch/elasticsearch:8.17.2

# start
docker start "elasticsearch"

#
