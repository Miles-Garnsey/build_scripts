
mvn -B org.jacoco:jacoco-maven-plugin:${JACOCO_VERSION}:prepare-agent surefire:test -DsurefireArgLine="-Xmx384m" \
    -Dtest=ReaperCassandraIT -Dgrim.reaper.min=${GRIM_MIN} -Dgrim.reaper.max=${GRIM_MAX} \
    -Dcucumber.options="$CUCUMBER_OPTIONS" org.jacoco:jacoco-maven-plugin:${JACOCO_VERSION}:report
