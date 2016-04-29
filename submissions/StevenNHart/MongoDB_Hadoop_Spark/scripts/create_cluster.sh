#!/bin/sh
##################################################################################
###
###     Name:           create_cluster.sh
###     Creator:        Steven N Hart, PhD
###     Function:       This script will deploy a configureable sharded mongodb
###											cluster in Docker containers with Apache Spark on HDFS
###
##################################################################################
##fix
usage ()
{
cat << EOF
##########################################################################################################
##
##	Usage: sh start_cluster.sh
##
## 	Optional Arguments:
##		-C 	Number of mongodb config servers [3] 
## 		-N 	Number of nodes to use for each replicaSet [3]
##		-R 	Number of replica sets [3]
##	-D 	Data directory, see explanation below [/data/db]
##		-h 	Print this help message
##
##
## Details
##  WTF is the \"-D\"" parameter about?
##		When running on a Mac, one can not map the /data/db directory to the local filesystem, so
##		the data are stored inside the container - which is not good. When doing the full scale
## 		analysis, this needs to be set as "/home/data/db"
##########################################################################################################
EOF
}

### Defaults ###
NUM_CONFIG_SERVERS=3
NUM_NODES=3
NUM_REPLSETS=3
MONGO_PORT=27017
DATA_DIR="/data/db"
##################################################################################
###
###     Parse Argument variables
###
##################################################################################
echo "Options specified: $@"

while getopts "C:N:R:D:h" OPTION; do
  case $OPTION in
    C)  NUM_CONFIG_SERVERS=$OPTARG ;;
		N)  NUM_NODES=$OPTARG ;;
		R)  NUM_REPLSETS=$OPTARG ;;
		D)  DATA_DIR=$OPTARG ;;
		h)  usage
				exit ;;
    \?) echo "Invalid option: -$OPTARG. See output file for usage." >&2
        usage
        exit ;;
    :)  echo "Option -$OPTARG requires an argument. See output file for usage." >&2
        usage
        exit ;;
  esac
done

# remove all running containers
docker rm -f $(docker ps -aq)

docker run  -d -p 172.17.0.1:53:53/udp --name skydns crosbymichael/skydns -nameserver 8.8.8.8:53 -domain docker
docker run  -d -v /var/run/docker.sock:/docker.sock --name skydock crosbymichael/skydock -ttl 30 -environment dev -s /docker.sock -domain docker -name skydns

for replSet in `seq 1 $NUM_REPLSETS`
do
 for node in `seq 1 $NUM_NODES`
  do
  if [ "$node" == 1 ] 
 	then
   echo "config = { _id: \"rs${replSet}\", members:[{ _id : $replSet, host : \"rs${replSet}-srv1.mongo-spark.dev.docker:27017\" }]};rs.initiate(config);" > replSet.js
   	echo "sh.addShard(\"rs${replSet}/rs${replSet}-srv1.mongo-spark.dev.docker:27017\");" >> router.js
  else
  	echo "rs.add({_id: \"rs${replSet}\",host: \"rs${replSet}-srv${node}.mongo-spark.dev.docker:27017\"});" >> replSet.js
  fi  	   
 docker run -w /home -v $PWD:/home --name rs${replSet}-srv${node} -d stevenhart/mongo-spark mongod --replSet rs${replSet} --dbpath $DATA_DIR
done

echo "rs.status();" >> replSet.js
INIT=`cat replSet.js`
STRING="docker run -w /home -v $PWD:/home -i -t stevenhart/mongo-spark mongo --host rs${replSet}-srv1.mongo-spark.dev.docker --eval '$INIT'"
echo "$STRING"
eval "$STRING"
done

docker run  -w /home -v $PWD:/home --name cfg1 -d stevenhart/mongo-spark mongod --configsvr --port 27017 --dbpath $DATA_DIR
docker run  -w /home -v $PWD:/home -p 27017:27017 --name router -d stevenhart/mongo-spark mongos --configdb cfg1.mongo-spark.dev.docker:27017

START_ROUTER=`cat router.js|tr "\n" " "`
STRING="docker run -it -w /home -v $PWD:/home stevenhart/mongo-spark mongo --host router.mongo-spark.dev.docker --eval '$START_ROUTER'"
eval $STRING
docker run -it -w /home -v $PWD:/home stevenhart/mongo-spark mongo --host router.mongo-spark.dev.docker --eval 'sh.status()'

rm replSet.js router.js