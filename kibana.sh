#!/bin/sh

# pull
docker pull "docker.elastic.co/kibana/kibana:8.17.2"

# run
docker run --rm --name kibana \
	--link elasticsearch:elasticsearch \
	-p 5601:5601 \
  -e ELASTICSEARCH_HOSTS=http://elasticsearch:9200 \
	-d docker.elastic.co/kibana/kibana:8.17.2

# start
docker start "kibana"

#
