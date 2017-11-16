#
#  Dockerfile for a GPDB SNE Sandbox Base Image
#
FROM centos:7
MAINTAINER anysky130@163.com

COPY * /tmp/
RUN yum install -y sudo wget git

# install dependency on centos
RUN curl -L https://raw.githubusercontent.com/greenplum-db/gpdb/master/README.CentOS.bash | /bin/bash
    # && cat /tmp/ld.so.conf.add >> /etc/ld.so.conf.d/usrlocallib.conf \
    # && ldconfig

# If you want to install and use gcc-6 by default, run:
# RUN sudo yum install -y centos-release-scl \
#     && sudo yum install -y devtoolset-6-toolchain \
#     && echo 'source scl_source enable devtoolset-6' >> ~/.bashrc

# unzip the file
WORKDIR /tmp/

RUN  wget https://github.com/greenplum-db/gpdb/archive/5.1.0.tar.gz
#RUN  unzip /tmp/gpdb-5.1.0.zip -d /tmp/ 

RUN tar -zxf /tmp/5.1.0.tar.gz -C /tmp/

# install optimizer
WORKDIR /tmp/
RUN git clone https://github.com/ninja-build/ninja.git
WORKDIR /tmp/ninjia/
RUN ls && pwd && /tmp/ninjia/configure.py --bootstrap

WORKDIR /tmp/
RUN git clone https://github.com/greenplum-db/gporca.git && git pull --ff-only
WORKDIR /tmp/gporca/
RUN cmake -GNinja -H. -Bbuild \
    && ninja install -C build

RUN ln -sf /usr/bin/cmake3 /usr/local/bin/cmake
RUN echo "/usr/local/lib" >> /etc/ld.so.conf
RUN echo "/usr/local/lib64" >> /etc/ld.so.conf
RUN cat /etc/ld.so.conf
RUN ldconfig

# RUN ln -sf /usr/bin/cmake3 /usr/local/bin/cmake
WORKDIR /tmp/gpdb-5.1.0/depends
RUN conan remote add conan-gpdb https://api.bintray.com/conan/greenplum-db/gpdb-oss \
    && conan install --build

WORKDIR /tmp/gpdb-5.1.0

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
        && cat /tmp/sysctl.conf.add >> /etc/sysctl.conf \
        && cat /tmp/limits.conf.add >> /etc/security/limits.conf \
        && echo "localhost" > /tmp/gpdb-hosts \
        && chmod 777 /tmp/gpinitsystem_singlenode \
        && hostname > ~/orig_hostname \
        && mv /tmp/run.sh /usr/local/bin/run.sh \
        && chmod +x /usr/local/bin/run.sh \
        && /usr/sbin/groupadd gpadmin \
        && /usr/sbin/useradd gpadmin -g gpadmin -G wheel \
        && echo "trsadmin"|passwd --stdin gpadmin \
        && echo "gpadmin        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers \
        && mv /tmp/bash_profile /home/gpadmin/.bash_profile \
        && chown -R gpadmin: /home/gpadmin \
        && mkdir -p /gpdata/master /gpdata/segments \
        && chown -R gpadmin: /gpdata \
        && chown -R gpadmin: /usr/local/green* \
        && service sshd start \
        && su gpadmin -l -c "source /usr/local/gpdb/greenplum_path.sh;gpssh-exkeys -f /tmp/gpdb-hosts"  \
        && su gpadmin -l -c "source /usr/local/gpdb/greenplum_path.sh;gpinitsystem -a -c  /tmp/gpinitsystem_singlenode -h /tmp/gpdb-hosts; exit 0 "\
        && su gpadmin -l -c "export MASTER_DATA_DIRECTORY=/gpdata/master/gpseg-1;source /usr/local/gpdb/greenplum_path.sh;psql -d template1 -c \"alter user gpadmin password 'trsadmin'\"; createdb gpadmin;  exit 0"


EXPOSE 5432 22

VOLUME /gpdata
# Set the default command to run when starting the container

CMD echo "127.0.0.1 $(cat ~/orig_hostname)" >> /etc/hosts \
        && service sshd start \
#       && sysctl -p \
        && su gpadmin -l -c "/usr/local/bin/run.sh" \
        && /bin/bash
