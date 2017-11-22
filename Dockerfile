#
#  Dockerfile for a GPDB SNE Sandbox Base Image
#
FROM centos:latest
MAINTAINER anysky130@163.com

COPY * /tmp/
RUN yum install -y sudo wget git openssl openssl-devel openssh-server;
RUN yum clean all && yum swap -y fakesystemd systemd
RUN ls /usr/bin
RUN ls /usr/local/bin
# INSTALL DEPENDENCY ON CENTOS
RUN curl -L https://raw.githubusercontent.com/greenplum-db/gpdb/master/README.CentOS.bash | /bin/bash
    # && cat /tmp/ld.so.conf.add >> /etc/ld.so.conf.d/usrlocallib.conf \
    # && ldconfig
RUN ln -sf /usr/bin/cmake3 /usr/local/bin/cmake
RUN echo "export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/sbin/:/bin/:/usr/sbin/:/usr/bin/:/root/bin/" >> /root/.bash_profile
RUN source /root/.bash_profile
RUN echo $PATH
# If you want to install and use gcc-6 by default, run:
# RUN sudo yum install -y centos-release-scl \
#     && sudo yum install -y devtoolset-6-toolchain \
#     && echo 'source scl_source enable devtoolset-6' >> ~/.bashrc

# ########### INSTALL COMPILER OPTIMIZER: NINJA (QUICK COMPILER)
# # https://github.com/ninja-build/ninja
# WORKDIR /tmp/
# RUN git clone https://github.com/ninja-build/ninja.git
# WORKDIR /tmp/ninja/
# RUN /tmp/ninja/configure.py --bootstrap
# RUN cp ninja /usr/bin/


########### INSTALL OPTIMIZER DEPENDENCY: GP-XERCES
# https://github.com/greenplum-db/gp-xerces
WORKDIR /tmp/
RUN git clone https://github.com/greenplum-db/gp-xerces.git
WORKDIR /tmp/gp-xerces
RUN chmod +x ./configure
RUN mkdir build
WORKDIR /tmp/gp-xerces/build
RUN ../configure --prefix=/opt/gp-xerces && make && make install

########### INSTALL GREENPLUM QUERY OPTIMIZER: GPORCA
# https://github.com/greenplum-db/gporca.git
WORKDIR /tmp/
RUN wget https://github.com/greenplum-db/gporca/archive/v2.46.6.tar.gz
RUN tar -zxf /tmp/v2.46.6.tar.gz -C /tmp/
# RUN git clone https://github.com/greenplum-db/gporca.git
WORKDIR /tmp/gporca-2.46.6/


RUN mkdir build
WORKDIR /tmp/gporca-2.46.6/build
RUN cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/opt/gp-orca -D XERCES_INCLUDE_DIR=/opt/gp-xerces/include -D XERCES_LIBRARY=/opt/gp-xerces/lib/libxerces-c.so ..\
      && make -j 32 \
      && make install

# RUN cmake -GNinja -H. -Bbuild -D XERCES_INCLUDE_DIR=/opt/gp_xerces/include -D XERCES_LIBRARY=/opt/gp_xerces/lib/libxerces-c.so ..
# RUN cmake -GNinja -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/opt/gp-orca -D XERCES_INCLUDE_DIR=/opt/gp-xerces/include -D XERCES_LIBRARY=/opt/gp-xerces/lib/libxerces-c.so -H. -Bbuild
# #RUN cmake -GNinja -H. -Bbuild
# RUN ninja install -C build
# # running a GPOARC test
# # RUN ctest -j7 --output-on-failure

RUN echo "/usr/local/lib" >> /etc/ld.so.conf
RUN echo "/usr/local/lib64" >> /etc/ld.so.conf
RUN echo "/opt/gp-orca/lib" >> /etc/ld.so.conf
RUN cat /etc/ld.so.conf
RUN ldconfig


########### INSTALL GREENPLUM 5.1.0
WORKDIR /tmp/
RUN  wget https://github.com/greenplum-db/gpdb/archive/5.1.0.tar.gz
RUN tar -zxf /tmp/5.1.0.tar.gz -C /tmp/
# WORKDIR /tmp/gpdb-5.1.0/depends
# RUN conan remote add conan-gpdb https://api.bintray.com/conan/greenplum-db/gpdb-oss \
#     && conan install --build

# Configure build environment to install at /opt/gpdb

WORKDIR /tmp/gpdb-5.1.0
RUN  ./configure --with-perl --with-python --with-libxml --with-gssapi --prefix=/opt/gpdb --with-includes=/usr/local/include:/opt/gp-orca/include:/opt/gp-xerces/include --with-libraries=/usr/local/lib:/usr/local/lib64:/opt/gp-orca/lib:/opt/gp-xerces/lib \
     # Compile and install
     && make -j8 \
     && make -j8 install \
     # Bring in greenplum environment into your running shell
     && source /opt/gpdb/greenplum_path.sh
     # Start demo cluster
     # && make create-demo-cluster \
     # (gpdemo-env.sh contains __PGPORT__ and __MASTER_DATA_DIRECTORY__ values)
     # && source gpAux/gpdemo/gpdemo-env.sh

########### SETTING GREENPLUM DATA DIRECTORY
RUN mkdir /gpdata
# RUN DATADIRS=/gpdata MASTER_PORT=15432 PORT_BASE=25432 make cluster

########### SETTING FOR SYSTEM BASIC OPTIMIZATION
RUN echo root:trsadmin | chpasswd \
    && cat /tmp/sysctl.conf.add >> /etc/sysctl.conf \
    && cat /tmp/limits.conf.add >> /etc/security/limits.conf \
    && chmod 777 /tmp/gpinitsystem_singlenode \
    && hostname > /tmp/cluster_hostname \
    && mv /tmp/run.sh /usr/local/bin/run.sh \
    && chmod +x /usr/local/bin/run.sh \
    && /usr/sbin/groupadd gpadmin \
    && /usr/sbin/useradd gpadmin -g gpadmin -G wheel \
    && echo "trsadmin"|passwd --stdin gpadmin \
    && echo "gpadmin        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers \
    && mv /tmp/singlenode_hostlist /home/gpadmin/singlenode_hostlist \
    && mv /tmp/gpinitsystem_singlenode /home/gpadmin/gpinitsystem_singlenode \
    && mv /tmp/bash_profile /home/gpadmin/.bash_profile \
    && chown -R gpadmin: /home/gpadmin \
    && mkdir -p /gpdata/master /gpdata/segments /gpdata/segmentmirror \
    && chown -R gpadmin: /gpdata \
    && chown -R gpadmin: /opt/gpdb/green*

# NECESSARY: key exchange with ourselves - needed by single-node greenplum and hadoop
# RUN systemctl start sshd && ssh-keygen -t rsa -q -f /root/.ssh/id_rsa -P "" &&\
RUN /usr/bin/sshd && ssh-keygen -t rsa -q -f /root/.ssh/id_rsa -P "" &&\
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && ssh-keyscan -t rsa localhost >> /root/.ssh/known_hosts &&\
ssh-keyscan -t rsa localhost >> /root/.ssh/known_hosts

RUN su gpadmin -l -c "source /opt/gpdb/greenplum_path.sh;gpssh-exkeys -h localhost"  \
    && hostname > /docker_hostname_at_moment_of_gpinitsystem &&\
    && su gpadmin -l -c "source /opt/gpdb/greenplum_path.sh;gpinitsystem -a -c  /tmp/gpinitsystem_singlenode -h localhost; exit 0 "\
    && su gpadmin -l -c "export MASTER_DATA_DIRECTORY=/gpdata/master/gpseg-1;source /opt/gpdb/greenplum_path.sh;psql -d template1 -c \"alter user gpadmin password 'trsadmin'\"; createdb gpadmin;  exit 0"

# INITIALIZE GPDB SYSTEM
# HACK: note, capture of unique docker hostname -- at this point, the hostname gets embedded into the installation ... :(
# RUN systemctl start sshd &&\
RUN /usr/bin/sshd &&\
    su gpadmin -l -c "gpinitsystem -a -D -c /home/gpadmin/gpinitsystem_singlenode --su_password=secret;"; exit 0;

# HACK: docker_transient_hostname_workaround, explanation:
#
# When gpinitsystem runs, it embeds the hostname (at that moment) into the installation.  Since Docker generates a new
# random hostname each time it runs, the hostname that is embedded, will never work again.  When you run `gpstart`, if
# the embedded hostname is not a valid DNS name, it will fail with this error:
#
# gpadmin-[ERROR]:-gpstart failed.  exiting...
# <snip>
#    addrinfo = socket.getaddrinfo(hostToPing, None)
# gaierror: [Errno -2] Name or service not known
#
# (You can reproduce this by removing the `docker_transient_hostname_workaround` bit from the CMD at the bottom.)
#
# So what we do here is to capture the random hostname at the moment that gpinitsystem is run, and later we can append
# it to /etc/hosts when we run `gpstart` -- this seems to keep it happy.
#
COPY /tmp/docker_transient_hostname_workaround.sh /home/gpadmin/docker_transient_hostname_workaround.sh
RUN chmod +x /home/gpadmin/docker_transient_hostname_workaround.sh


# WIDE OPEN GPDB ACCESS PERMISSIONS
# COPY /tmp/allow_all_password_incoming_pg_hba.conf /gpdata/gpmaster/gpsne-1/pg_hba.conf
COPY /tmp/allow_all_password_incoming_pg_hba.conf /gpdata/gpmaster/gpseg-1/pg_hba.conf
COPY /tmp/postgresql.conf /gpdata/gpmaster/gpseg-1/postgresql.conf
EXPOSE 5432 22

VOLUME /gpdata


########### START THE RUN.SH WHEN CONTAINER START
# Set the default command to run when starting the container
# CMD echo "127.0.0.1 $(cat /tmp/cluster_hostname)" >> /etc/hosts \
CMD ./docker_transient_hostname_workaround.sh \
        # && systemctl start sshd \
        && /usr/bin/sshd \
        && sysctl -p \
        && su gpadmin -l -c "/usr/local/bin/run.sh" \
        && /bin/bash
