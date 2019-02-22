if [ "${1}" != "release" -a "${1}" != "snapshots" ]; then
	echo "Must have one argument, either \"release\" or \"snapshots\"."
	exit 1
fi

docker stop /local-nexus
docker rm /local-nexus

docker pull sonatype/nexus:2.14.11-01 && \
docker run -d -p 8081:8081 --name local-nexus sonatype/nexus:2.14.11-01

until $(curl --output /dev/null --silent --head --fail http://localhost:8081/nexus/); do
  printf '.'
  sleep 5
done

timestamp=$(date +%s)
mkdir -p tmp/$timestamp/cli

./gradlew clean && \

mavenProfileUrl=`./gradlew -PlocalNexus -P${1} :extensions:maven-profile:publish --info | grep Uploading | grep '.jar ' | grep -v -e '-sources' -e '-tests' | cut -d' ' -f2` && \

mavenProfileUrl="http://localhost:8081/nexus/content/groups/public/"$mavenProfileUrl

curl -s $mavenProfileUrl -o tmp/$timestamp/maven_profile.jar

./gradlew -PlocalNexus -P${1} --refresh-dependencies clean check :cli:smokeTests && \

bladeCliUrl=`./gradlew -PlocalNexus -P${1} :cli:publish --info | grep Uploading | grep '.jar ' | grep -v -e '-sources' -e '-tests' | cut -d' ' -f2` && \

bladeCliUrl="http://localhost:8081/nexus/content/groups/public/"$bladeCliUrl

curl -s $bladeCliUrl -o tmp/$timestamp/cli/blade.jar

mavenProfileJar=`jar -tf tmp/$timestamp/cli/blade.jar | grep "maven.profile-"`

unzip -p tmp/$timestamp/cli/blade.jar $mavenProfileJar > tmp/$timestamp/cli/myExtractedMavenProfile.jar

echo $mavenProfileUrl
echo $bladeCliUrl
diff -s tmp/$timestamp/cli/myExtractedMavenProfile.jar tmp/$timestamp/maven_profile.jar

rm -rf tmp/