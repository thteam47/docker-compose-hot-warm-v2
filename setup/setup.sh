#!/bin/bash -ex

ES_URL=http://elasticsearch-hot:9200

echo "Load the relevant settings for ILM"

# Load the relevant settings for ILM
curl -s -H 'Content-Type: application/json' -XPUT ${ES_URL}/_cluster/settings -d@/opt/setup/cluster.json
curl -s -H 'Content-Type: application/json' -XPUT ${ES_URL}/_ilm/policy/logs-hot-warm -d@/opt/setup/ilm.json
curl -s -H 'Content-Type: application/json' -XPUT ${ES_URL}/_template/template_logs -d@/opt/setup/template_logS.json
curl -s -H 'Content-Type: application/json' -XPUT ${ES_URL}/testlog-000001 -d@/opt/setup/index.json

echo "Load the relevant settings for SLM"

# Load the relevant settings for SLM
curl -s -H 'Content-Type: application/json' -XPUT ${ES_URL}/_snapshot/logs-snapshots-repository -d@/opt/setup/snapshot_repository.json
curl -s -H 'Content-Type: application/json' -XPUT ${ES_URL}/_slm/policy/logs-snapshot-policy -d@/opt/setup/slm.json

echo "Done"