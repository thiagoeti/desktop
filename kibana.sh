#!/bin/sh

# pull
docker pull "elastic/kibana:9.1.3"

# drop
docker rm -f "kibana"

# run
docker run --name "kibana" \
	--link elasticsearch:elasticsearch \
	-p 5601:5601 \
	-e "ELASTICSEARCH_HOSTS=http://elasticsearch:9200" \
	-e "TZ=America/Sao_Paulo" \
	-e "XPACK_SECURITY_ENABLED=true" \
	-e "ELASTICSEARCH_USERNAME=kibana" \
	-e "ELASTICSEARCH_PASSWORD=***" \
	-d "elastic/kibana:9.1.3"

# start
docker start "kibana"

#
