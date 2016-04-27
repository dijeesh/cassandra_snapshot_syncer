#! /bin/bash

# 1. Clear old snapshots
#
# 	 When taking a snapshot, previous snapshot files are not automatically deleted. 
#    You should remove old snapshots that are no longer needed.
#
# 2. Take backup of cassandra configuration file
#
# 3. Take schema backup
#
# 	 Cassandra can only restore data from a snapshot when the table schema exists. 
#    It is recommended that you also backup the schema.
#
# 4. Take list of keyspaces and columnamilyName
#
#	 If the restore is done to a new server – make sure to create all keyspaces & columnfamilyName directories 
#	 the same as the source.
#
# 5. Retrieve the list of tokens associated each node
#
#	 If the restore is done to a new server, initial_token parameter required to start the node
#
# 6. Take snapshot
#
# 7. Sync snapshot to S3
#	 Snapshot will be synced to s3_bucket/hostname/week_number 
#
# 8. Sync Configurations to S3
#	 Configurations will be synced to s3_bucket/hostname/week_number/configs
#
# 9. Alerts and Notifications
#
# 10. Clean-up


BACKUP_DIR=/opt/cassandra_conf_backup
CAS_DATA_DIR=/var/lib/cassandra/data
readonly LOG=/var/log/cassandra_backup/snapshot_$(date +%Y%m%d).log
readonly WEEK=week_$(/bin/date +%V)
readonly SNAPSHOT=$(/bin/date +'%Y%m%d%H')

echo "$(date +%F-%H:%M:%S) Starting backup process at $(date)" > "$LOG"
	
	if [ -d  "$BACKUP_DIR" ]
		then
		echo "$(date +%F-%H:%M:%S) $BACKUP_DIR exist, Proceeding with backup process" >> "$LOG"
		else
		mkdir -p "$BACKUP_DIR"
		echo "$(date +%F-%H:%M:%S) Created backup directory, starting backup process" >> "$LOG"
	fi


# 1 Clear old snapshots
	nodetool clearsnapshot >> "$LOG"
	echo "$(date +%F-%H:%M:%S) Cleared previous snapshots" >> "$LOG"

# 2 Copy Cassandra configuration file
	cp  /etc/cassandra/conf/cassandra.yaml /opt/cassandra_conf_backup/
	echo "$(date +%F-%H:%M:%S) Taken backup of cassandra configuration file" >> "$LOG"

# 3 Take schema backup
#replace with find all keyspace and take schema backup

	cqlsh --ssl -e "DESC KEYSPACE DBMAME" > "$BACKUP_DIR"/db_schema.cql
	echo "$(date +%F-%H:%M:%S) Taken cassandra schema backup " >> "$LOG"


# 4 List keyspace and columnfamilyName for each keyspace
echo "$(date +%F-%H:%M:%S) Listing keyspace and communityfamilyNames " >> "$LOG"
	for i in $(ls -ll /var/lib/cassandra/data/ | awk '{print $9}') ; do 
		echo "#${i}" >> /opt/cassandra_conf_backup/keyspaces;
		ls -ll  /var/lib/cassandra/data/"$i" | awk '{print $9}'  >>/opt/cassandra_conf_backup/keyspaces ; 
		echo >> /opt/cassandra_conf_backup/keyspaces ; 
	done


# 5. Retrieve the list of tokens associated each node
echo "$(date +%F-%H:%M:%S) Retrieve the list of tokens associated to each node " >> "$LOG"
	for i in $(nodetool status | awk '/UN/{print $2}'); do
		echo "#${i}" >> /opt/cassandra_conf_backup/initial_tokens ;
		echo >>  /opt/cassandra_conf_backup/initial_tokens ;
		nodetool ring | grep "$i" |awk '{print $NF}' >>/opt/cassandra_conf_backup/initial_tokens;
		echo >>  /opt/cassandra_conf_backup/initial_tokens ;
	done


# 6. Take snapshot
echo "$(date +%F-%H:%M:%S) Taking cassandra snapshot " >> "$LOG"
	nodetool snapshot -t "$SNAPSHOT" >> "$LOG"

# 7 Sync snapshot  to S3

echo "$(date +%F-%H:%M:%S) Syncing cassandra snapshot to S3 bucket" >> "$LOG"


	CAS_DATA_DIR=/var/lib/cassandra/data
	for i in $(ls -ll "$CAS_DATA_DIR"/*/*/snapshots/ | grep "$CAS_DATA_DIR" | cut -d '/' -f 1-7); do
	aws s3 sync "$i"/snapshots/"$SNAPSHOT"/ s3://BUCKET/"$(hostname)"/"$WEEK""$i"/  ;
	done

	
# 8 sync configs
	echo "$(date +%F-%H:%M:%S) Syncing cassandra configurations to S3 bucket" >> "$LOG" 
	aws s3 sync $BACKUP_DIR/ s3://BUCKET/"$(hostname)"/"$WEEK"/configs/ >> "$LOG"

# 9 Cleanup

rm -rf /opt/cassandra_conf_backup/*
echo "$(date +%F-%H:%M:%S) S3 Upload complete " >> "$LOG"


# 10 Clear snapshots
	nodetool clearsnapshot >> "$LOG"
	echo "$(date +%F-%H:%M:%S) Cleared snapshots" >> "$LOG"


# 11 Mail Alert

echo "Cassandra backup and S3 sync completed for $(hostname)" | mail -s $(hostname)_backup_notification EMAIL 

