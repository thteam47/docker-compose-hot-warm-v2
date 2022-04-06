#!/bin/bash -ex

ES_URL=http://192.168.99.148:9200

echo "Load the relevant settings for ILM"

# Load the relevant settings for ILM
curl -XPUT ${ES_URL}/_cluster/settings -H 'Content-Type: application/json' -d@setup/cluster.json
curl -XPUT ${ES_URL}/_ilm/policy/logs-hot-warm -H 'Content-Type: application/json' -d@setup/ilm.json
curl -XPUT ${ES_URL}/_template/template_logs -H 'Content-Type: application/json' -d@setup/template_logS.json
curl -XPUT ${ES_URL}/testlog-000001 -H 'Content-Type: application/json' -d@setup/index.json

echo "Load the relevant settings for SLM"

# Load the relevant settings for SLM
curl -XPUT ${ES_URL}/_snapshot/logs-snapshots-repository -H 'Content-Type: application/json' -d@setup/snapshot_repository.json
curl -XPUT ${ES_URL}/_slm/policy/logs-snapshot-policy -H 'Content-Type: application/json' -d@setup/slm.json

echo "Done"