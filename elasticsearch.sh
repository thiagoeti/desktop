#!/bin/sh

# pull
docker pull "elastic/elasticsearch:9.1.3"

# volume
sudo docker volume create "elasticsearch"
sudo ln -s "/var/lib/docker/volumes/elasticsearch" "/data/volume/"

# drop
docker rm -f "elasticsearch"

# run
docker run --name "elasticsearch" \
	--cpus="4" \
	--memory="8g" \
	-p 9200:9200 \
	-p 9300:9300 \
	-v "/data":"/data" \
	-w "/data" \
	-e "discovery.type=single-node" \
	-e "ES_JAVA_OPTS=-Xms4g -Xmx4g" \
	-e "xpack.security.enabled=true" \
	-e "ELASTIC_USERNAME=elastic" \
	-e "ELASTIC_PASSWORD=master" \
	-e "TZ=America/Sao_Paulo" \
	-v "elasticsearch":"/usr/share/elasticsearch/data" \
	-d "elastic/elasticsearch:9.1.3"

# start
docker start "elasticsearch"

# password

cd /usr/share/elasticsearch
bin/elasticsearch-setup-passwords auto

#
