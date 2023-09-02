#!/bin/bash

CCM_NAME="test"
# set Cassandra version to first script argument, or 3.11.15 if no argument is specified
CASSANDRA_VERSION="binary:"${1:-"4.0.3"}
JDK_VENDOR=temurin

configure_ccm () {
  sed -i 's/#MAX_HEAP_SIZE="4G"/MAX_HEAP_SIZE="256m"/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra-env.sh
  sed -i 's/#HEAP_NEWSIZE="800M"/HEAP_NEWSIZE="200M"/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra-env.sh
  sed -i 's/_timeout_in_ms:.*/_timeout_in_ms: 60000/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/start_rpc: true/start_rpc: false/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/cross_node_timeout: false/cross_node_timeout: true/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/concurrent_reads: 32/concurrent_reads: 4/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/concurrent_writes: 32/concurrent_writes: 4/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/concurrent_counter_writes: 32/concurrent_counter_writes: 4/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/num_tokens: 256/num_tokens: 4/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/auto_snapshot: true/auto_snapshot: false/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/enable_materialized_views: true/enable_materialized_views: false/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/internode_compression: dc/internode_compression: none/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  sed -i 's/# file_cache_size_in_mb: 512/file_cache_size_in_mb: 1/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  echo 'phi_convict_threshold: 16' >> ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  if [[ "$CASSANDRA_VERSION" == *"trunk"* ]] || [[ "$CASSANDRA_VERSION" == *"4."* ]]; then
    sed -i 's/start_rpc: true//' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
    echo '-Dcassandra.max_local_pause_in_ms=15000' >> ~/.ccm/${CCM_NAME}/node$1/conf/jvm-server.options
    sed -i 's/#-Dcassandra.available_processors=number_of_processors/-Dcassandra.available_processors=2/' ~/.ccm/${CCM_NAME}/node$1/conf/jvm-server.options
    sed -i 's/diagnostic_events_enabled: false/diagnostic_events_enabled: true/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  else
    sed -i 's/start_rpc: true/start_rpc: false/' ~/.ccm/${CCM_NAME}/node$1/conf/cassandra.yaml
  fi
  # Fix for jmx connections randomly hanging
  echo "JVM_OPTS=\"\$JVM_OPTS -Djava.rmi.server.hostname=127.0.0.$i\"" >> ~/.ccm/${CCM_NAME}/node$1/conf/cassandra-env.sh
}

get_management_api_jars () {
  echo "Removing any Management API jars from /tmp and replacing with versions specified in pom.xml"
  rm /tmp/datastax-mgmtapi-*.jar
  # Do some fancy pom.xml parsing to figure out which version of the Management API client we are using
  MGMT_API_VERSION=`mvn dependency:tree -f src/server/pom.xml |grep datastax-mgmtapi-client-openapi|cut -d ":" -f 4`
  # Download the Management API bundle
  mvn dependency:copy -Dartifact=io.k8ssandra:datastax-mgmtapi-server:$MGMT_API_VERSION -f src/server/pom.xml -DoutputDirectory=/tmp -Dmdep.stripVersion=true -Dmdep.overWriteReleases=true
  # Unzip the agent for the version of Cassandra
  if [[ "$CASSANDRA_VERSION" == *"3.11"* ]]; then
     mvn dependency:copy -Dartifact=io.k8ssandra:datastax-mgmtapi-agent-3.x:$MGMT_API_VERSION -f src/server/pom.xml -DoutputDirectory=/tmp -Dmdep.stripVersion=true -Dmdep.overWriteReleases=true
     # curl -s -o /tmp/datastax-mgmtapi-agent-3.x.jar https://dl.cloudsmith.io/public/thelastpickle/reaper-mvn/maven/io/k8ssandra/datastax-mgmtapi-agent-3.x/0.1.0-507f418/datastax-mgmtapi-agent-3.x-0.1.0-507f418.jar
     ln -s /tmp/datastax-mgmtapi-agent-3.x.jar /tmp/datastax-mgmtapi-agent.jar
  elif [[ "$CASSANDRA_VERSION" == *"4.0"* ]]; then
     mvn dependency:copy -Dartifact=io.k8ssandra:datastax-mgmtapi-agent-4.x:$MGMT_API_VERSION -f src/server/pom.xml -DoutputDirectory=/tmp -Dmdep.stripVersion=true -Dmdep.overWriteReleases=true
     ln -s /tmp/datastax-mgmtapi-agent-4.x.jar /tmp/datastax-mgmtapi-agent.jar
  elif [[ "$CASSANDRA_VERSION" == *"4.1"* ]]; then
     mvn dependency:copy -Dartifact=io.k8ssandra:datastax-mgmtapi-agent-4.1.x:$MGMT_API_VERSION -f src/server/pom.xml -DoutputDirectory=/tmp -Dmdep.stripVersion=true -Dmdep.overWriteReleases=true
     ln -s /tmp/datastax-mgmtapi-agent-4.1.x.jar /tmp/datastax-mgmtapi-agent.jar
  fi
}

add_management_api () {
  echo "JVM_OPTS=\"\$JVM_OPTS -javaagent:/tmp/datastax-mgmtapi-agent.jar\"" >> ~/.ccm/${CCM_NAME}/node$1/conf/cassandra-env.sh
}

# Activate Python environment with CCM
# . ~/workspace/cassandra-medusa/venv/bin/activate

# delete test cluster if it exists
if ccm list|grep -q ${CCM_NAME};
then
  echo "Removing \"${CCM_NAME}\" CCM cluster"
  ccm remove ${CCM_NAME}
else
  echo "No \"${CCM_NAME}\" CCM cluster"
  ccm list
fi

sdk use java 11.0.19-tem
rm -rf /home/turbo-admin/.ccm/test

# create a new test CCM cluster
echo "Creating \"${CCM_NAME}\" cluster, CCM Cassandra version: $CASSANDRA_VERSION"
ccm create test -v ${CASSANDRA_VERSION}

# populate the cluster with 2 nodes
ccm populate --vnodes -n 2:0

# Download Management API jarfiles
get_management_api_jars

# use "2:0" to ensure the first datacenter name is "dc1" instead of "datacenter1", so to be compatible with CircleCI tests
for i in `seq 1 2` ; do
  sed -i 's/LOCAL_JMX=yes/LOCAL_JMX=no/' ~/.ccm/${CCM_NAME}/node$i/conf/cassandra-env.sh
  sed -i 's/etc\/cassandra\/jmxremote.password/home\/runner\/.local\/jmxremote.password/' ~/.ccm/${CCM_NAME}/node$i/conf/cassandra-env.sh
  # relevant for elassandra, ensure the node's dc name matches the client
  sed -i 's/DC1/dc1/' ~/.ccm/${CCM_NAME}/node$i/conf/cassandra-rackdc.properties
  sed -i 's/PropertyFileSnitch/GossipingPropertyFileSnitch/' ~/.ccm/${CCM_NAME}/node$i/conf/cassandra.yaml
  configure_ccm $i
  add_management_api $i
done

# start CCM
ccm start -v --no-wait --skip-wait-other-notice || true
echo "${TEST_TYPE}" | grep -q ccm && sleep 30
ccm status

# Stop CCM and dump the startup commands for Management API
echo "Stopping CCM so that it can be started via Management API"
ccm stop
ccm status
if [[ "$CASSANDRA_VERSION" == *"trunk"* ]] || [[ "$CASSANDRA_VERSION" == *"4."* ]]; then
  echo "Using Cassandra 4.0 or newer, set JAVA_HOME to JDK11"
else
  echo "Using Cassandra 3.11, set JAVA_HOME to JDK8"
fi
for i in `seq 1 2` ; do
  echo "To run node$i:"
  echo "JAVA_HOME=$JAVA_HOME MGMT_API_LOG_DIR=/tmp/log/cassandra$i java -jar /tmp/datastax-mgmtapi-server.jar --db-socket=/tmp/db$i.sock --host=unix:///tmp/mgmtapi$i.sock --host=http://127.0.0.$i:8080 --db-home=`dirname ~/.ccm/test/node$i`/node$i"
done
