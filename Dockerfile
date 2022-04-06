FROM docker.elastic.co/elasticsearch/elasticsearch:7.10.0

# This is an ugly workaround to create a backup folder with the right permissions
# If you just create it through the bind mount it would be owned by root,
# which isn't writeable by the Elasticsearch process
RUN mkdir /usr/share/elasticsearch/snapshots/
RUN chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/snapshots/
