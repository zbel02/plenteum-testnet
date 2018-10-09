# daemon runs in the background
# run something like tail /var/log/plenteumd/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/plenteumd:/var/lib/plenteumd -v $(pwd)/wallet:/home/plenteum --rm -ti plenteum:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG TURTLECOIN_BRANCH=master
ENV TURTLECOIN_BRANCH=${TURTLECOIN_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/plenteum/plenteum.git /src/plenteum && \
    cd /src/plenteum && \
    git checkout $TURTLECOIN_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/Plenteumd /usr/local/bin/Plenteumd && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/Plenteumd && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/plenteum && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev librocksdb-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the plenteumd service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/plenteumd plenteumd && \
    useradd -s /bin/bash -m -d /home/plenteum plenteum && \
    mkdir -p /etc/services.d/plenteumd/log && \
    mkdir -p /var/log/plenteumd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/plenteumd/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/plenteumd/run && \
    echo "cd /var/lib/plenteumd" >> /etc/services.d/plenteumd/run && \
    echo "export HOME /var/lib/plenteumd" >> /etc/services.d/plenteumd/run && \
    echo "s6-setuidgid plenteumd /usr/local/bin/Plenteumd" >> /etc/services.d/plenteumd/run && \
    chmod +x /etc/services.d/plenteumd/run && \
    chown nobody:nogroup /var/log/plenteumd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/plenteumd/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/plenteumd/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/plenteumd" >> /etc/services.d/plenteumd/log/run && \
    chmod +x /etc/services.d/plenteumd/log/run && \
    echo "/var/lib/plenteumd true plenteumd 0644 0755" > /etc/fix-attrs.d/plenteumd-home && \
    echo "/home/plenteum true plenteum 0644 0755" > /etc/fix-attrs.d/plenteum-home && \
    echo "/var/log/plenteumd true nobody 0644 0755" > /etc/fix-attrs.d/plenteumd-logs

VOLUME ["/var/lib/plenteumd", "/home/plenteum","/var/log/plenteumd"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/plenteum export HOME /home/plenteum s6-setuidgid plenteum /bin/bash"]