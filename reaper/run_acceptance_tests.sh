ccm create test -v binary:4.0.1
sudo ifconfig lo0 alias 127.0.0.2 up
ccm populate --vnodes -n 2:0
for i in `seq 1 2` ; do
          sed -i ''  -e 's/LOCAL_JMX=yes/LOCAL_JMX=no/' ~/.ccm/test/node$i/conf/cassandra-env.sh
          sed -i '' -e 's/etc\/cassandra\/jmxremote.password/home\/runner\/.local\/jmxremote.password/' ~/.ccm/test/node$i/conf/cassandra-env.sh
          # relevant for elassandra, ensure the node's dc name matches the client
          sed -i ''  -e 's/DC1/dc1/' ~/.ccm/test/node$i/conf/cassandra-rackdc.properties
          sed -i ''  -e 's/PropertyFileSnitch/GossipingPropertyFileSnitch/' ~/.ccm/test/node$i/conf/cassandra.yaml
          configure_ccm $i
done;
ccm start -v --no-wait --skip-wait-other-notice
export JACOCO_VERSION=0.8.6
mvn -B org.jacoco:jacoco-maven-plugin:${JACOCO_VERSION}:prepare-agent surefire:test -DsurefireArgLine="-Xmx384m" \
    -Dtest=ReaperCassandraIT -Dgrim.reaper.min=${3} -Dgrim.reaper.max=${4} \
    -Dcucumber.options="$CUCUMBER_OPTIONS" org.jacoco:jacoco-maven-plugin:${JACOCO_VERSION}:report

configure_ccm () {
  sed  -i ''  -e 's/#MAX_HEAP_SIZE="4G"/MAX_HEAP_SIZE="256m"/' ~/.ccm/test/node$1/conf/cassandra-env.sh
  sed  -i ''  -e 's/#HEAP_NEWSIZE="800M"/HEAP_NEWSIZE="200M"/' ~/.ccm/test/node$1/conf/cassandra-env.sh
  sed  -i ''  -e 's/_timeout_in_ms:.*/_timeout_in_ms: 60000/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/start_rpc: true/start_rpc: false/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/cross_node_timeout: false/cross_node_timeout: true/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/concurrent_reads: 32/concurrent_reads: 4/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/concurrent_writes: 32/concurrent_writes: 4/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/concurrent_counter_writes: 32/concurrent_counter_writes: 4/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/num_tokens: 256/num_tokens: 4/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/auto_snapshot: true/auto_snapshot: false/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/enable_materialized_views: true/enable_materialized_views: false/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/internode_compression: dc/internode_compression: none/' ~/.ccm/test/node$1/conf/cassandra.yaml
  sed  -i ''  -e 's/# file_cache_size_in_mb: 512/file_cache_size_in_mb: 1/' ~/.ccm/test/node$1/conf/cassandra.yaml
  echo 'phi_convict_threshold: 16' >> ~/.ccm/test/node$1/conf/cassandra.yaml
  if [[ "$CASSANDRA_VERSION" == *"trunk"* ]] || [[ "$CASSANDRA_VERSION" == *"4."* ]]; then
    sed  -i ''  -e 's/start_rpc: true//' ~/.ccm/test/node$1/conf/cassandra.yaml
    echo '-Dcassandra.max_local_pause_in_ms=15000' >> ~/.ccm/test/node$1/conf/jvm-server.options
    sed  -i ''  -e 's/#-Dcassandra.available_processors=number_of_processors/-Dcassandra.available_processors=2/' ~/.ccm/test/node$1/conf/jvm-server.options
    sed  -i ''  -e 's/diagnostic_events_enabled: false/diagnostic_events_enabled: true/' ~/.ccm/test/node$1/conf/cassandra.yaml
  else
    sed  -i ''  -e 's/start_rpc: true/start_rpc: false/' ~/.ccm/test/node$1/conf/cassandra.yaml
  fi
  # Fix for jmx connections randomly hanging
  echo "JVM_OPTS=\"\$JVM_OPTS -Djava.rmi.server.hostname=127.0.0.$i\"" >> ~/.ccm/test/node$1/conf/cassandra-env.sh
}
