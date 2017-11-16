#
#  Dockerfile for a GPDB SNE Sandbox Base Image
#

FROM centos:7
MAINTAINER anysky130@163.com


USER root
RUN mkdir /download
ADD . /download/

RUN yum install -y sudo wget

# install dependency on centos
RUN curl -L https://raw.githubusercontent.com/greenplum-db/gpdb/master/README.CentOS.bash | /bin/bash \
    && cat /download/configs/ld.so.conf.add >> /etc/ld.so.conf \
    && ldconfig

# If you want to install and use gcc-6 by default, run:
# RUN sudo yum install -y centos-release-scl \
#     && sudo yum install -y devtoolset-6-toolchain \
#     && echo 'source scl_source enable devtoolset-6' >> ~/.bashrc

# unzip the file
RUN  cd /download
# RUN  wget -O gpdb-5.1.0.tar.gz https://github.com/greenplum-db/gpdb/archive/5.1.0.tar.gz
RUN  tar -xzf gpdb-5.1.0.tar.gz -C /download
RUN  echo "check current directory"
RUN  pwd && ls

# install optimizer
RUN cd /download/gpdb-5.1.0/depends \
    && conan remote add conan-gpdb https://api.bintray.com/conan/greenplum-db/gpdb-oss \
    && conan install --build \
    && cd ..

# Configure build environment to install at /usr/local/gpdb
RUN  ./configure --with-perl --with-python --with-libxml --with-gssapi --prefix=/usr/local/gpdb \
     # Compile and install
     && make -j8 \
     && make -j8 install \
     # Bring in greenplum environment into your running shell
     && source /usr/local/gpdb/greenplum_path.sh \
     # Start demo cluster
     && make create-demo-cluster \
     # (gpdemo-env.sh contains __PGPORT__ and __MASTER_DATA_DIRECTORY__ values)
     && source gpAux/gpdemo/gpdemo-env.sh


# setting the data
RUN mkdir /gpdata
RUN DATADIRS=/gpdata MASTER_PORT=15432 PORT_BASE=25432 make cluster

RUN echo root:trsadmin | chpasswd \
        && cat /download/configs/sysctl.conf.add >> /etc/sysctl.conf \
        && cat /download/configs/limits.conf.add >> /etc/security/limits.conf \
        && echo "localhost" > /download/configs/gpdb-hosts \
        && chmod 777 /download/configs/gpinitsystem_singlenode \
        && hostname > ~/orig_hostname \
        && mv /download/configs/run.sh /usr/local/bin/run.sh \
        && chmod +x /usr/local/bin/run.sh \
        && /usr/sbin/groupadd gpadmin \
        && /usr/sbin/useradd gpadmin -g gpadmin -G wheel \
        && echo "trsadmin"|passwd --stdin gpadmin \
        && echo "gpadmin        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers \
        && mv /download/configs/bash_profile /home/gpadmin/.bash_profile \
        && chown -R gpadmin: /home/gpadmin \
        && mkdir -p /gpdata/master /gpdata/segments \
        && chown -R gpadmin: /gpdata \
        && chown -R gpadmin: /usr/local/green* \
        && service sshd start \
        && su gpadmin -l -c "source /usr/local/gpdb/greenplum_path.sh;gpssh-exkeys -f /download/gpdb-hosts"  \
        && su gpadmin -l -c "source /usr/local/gpdb/greenplum_path.sh;gpinitsystem -a -c  /download/gpinitsystem_singlenode -h /download/gpdb-hosts; exit 0 "\
        && su gpadmin -l -c "export MASTER_DATA_DIRECTORY=/gpdata/master/gpseg-1;source /usr/local/gpdb/greenplum_path.sh;psql -d template1 -c \"alter user gpadmin password 'trsadmin'\"; createdb gpadmin;  exit 0"


EXPOSE 5432 22

VOLUME /gpdata
# Set the default command to run when starting the container

CMD echo "127.0.0.1 $(cat ~/orig_hostname)" >> /etc/hosts \
        && service sshd start \
#       && sysctl -p \
        && su gpadmin -l -c "/usr/local/bin/run.sh" \
        && /bin/bash
