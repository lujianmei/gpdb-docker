#!/bin/bash

#echo "host all all 0.0.0.0/0 md5" >> /gpdata/master/gpseg-1/pg_hba.conf
export MASTER_DATA_DIRECTORY=/gpdata/master/gpseg-1
source /opt/gpdb/greenplum_path.sh
gpstart -a --verbose
psql -d template1 -c "alter user gpadmin password 'trsadmin'"
