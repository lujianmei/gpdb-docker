
# gpdb-docker
Pivotal Greenplum Database Base Docker Image (5.1.0)

[![](https://images.microbadger.com/badges/version/pivotaldata/gpdb-base.svg)](https://microbadger.com/images/pivotaldata/gpdb-base "Get your own version badge on microbadger.com") [![Build Status](https://travis-ci.org/lujianmei/gpdb-docker.svg?branch=master)](https://travis-ci.org/lujianmei/gpdb-docker)

## Information ##
Current repository build based on Greenplum 5.1.0 version, which is using docker compose to build, include a docker master container holding a Master node, and two segment containers holding a segment node for each of them.  So when the docker compose startup, it will launch three Containers up.

## Startup the Containers ##
1. First of all, you need to make sure the docker has been installed in your computer.
2. 

# Building the Docker Image
For the purpose of changing the build information, rebuilding all images, you need to do as following step:

git clone https://github.com/lujianmei/gpdb-docker.git gpdb-docker
cd gpdb-docker
gpdb-docker.sh build .

# Running the Docker Image
docker run -i -p 5432:5432 [tag]

# Container Accounts
root/pivotal

gpadmin/pivotal

# Using psql in the Container
su - gpadmin

psql

# Using pgadmin outside the Container
Launch pgAdmin3

Create new connection using IP Address and Port # (5432)
