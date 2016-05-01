# cassandra_snapshot_syncer
Simple bash script to take cassandra snapshot and sync to Amazon S3 bucket


This script will hepls you to take a cassandra snapshot and sync it to S3 bucket. 

Requirements
=======

1. You should have aws command line tool installed in your system

    easy_install awscli

    aws --configure

2. You should have .cassandra/cqlshrc in place ( Connection and SSL details )

3. Postfix MTA for sending E-mail Notifications.


Notes
=======

To take backups of a multinode cluster, you may set a cronjob in all cluster nodes and run the script at same time.




