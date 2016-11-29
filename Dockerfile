# dpdk_iperf3
#
# Borrows in part from the following prior work:
#
# - https://github.com/opendp/dpdk-iperf
# - https://github.com/opendp/dpdk-ans
# - https://github.com/redhat-performance/docker-dpdk
# - https://github.com/nerdalert/iperf3/blob/master/Dockerfile
#
# Run as Server:
# docker run  -it --rm --name=iperf3-srv -p 5201:5201 quay.io/connordoyle/dpdk_iperf3 -s
#
# Run as Client (first get server IP address):
# docker inspect --format "{{ .NetworkSettings.IPAddress }}" iperf3-srv
# docker run  -it --rm quay.io/connordoyle/dpdk_iperf3 -c <SERVER_IP>
FROM ubuntu:16.04
MAINTAINER Connor Doyle <connor.p.d@gmail.com>

# RUN docker run -it --privileged \
#  -v /sys/bus/pci/devices:/sys/bus/pci/devices \
#  -v /sys/kernel/mm/hugepages:/sys/kernel/mm/hugepages \
#  -v /sys/devices/system/node:/sys/devices/system/node \
#  -v /dev:/dev

# Install dependencies, then trash the cache
RUN apt-get update && apt-get install -y \
    binutils \
    build-essential \
    gcc \
    git \
    libc6-dev \
    libpcap-dev \
    libssl1.0.0 \
    linux-headers-generic \
    make \
    pciutils \
    xz-utils && \
    rm -rf /var/lib/apt/lists/*

# Fetch and extract DPDK source.
ADD http://fast.dpdk.org/rel/dpdk-16.07.1.tar.xz /root/
RUN mkdir /root/dpdk && \
    tar -xJf /root/dpdk-16.07.1.tar.xz -C /root/dpdk && \
    rm /root/dpdk-16.07.1.tar.xz

# Build DPDK
WORKDIR /root/dpdk/dpdk-stable-16.07.1
ENV RTE_SDK=/root/dpdk/dpdk-stable-16.07.1
ENV RTE_TARGET=x86_64-native-linuxapp-gcc
ENV RTE_KERNELDIR /lib/modules/4.4.0-47-generic/build

RUN make config T=x86_64-native-linuxapp-gcc O=x86_64-native-linuxapp-gcc && \
    make O=x86_64-native-linuxapp-gcc

# Build ANS
ENV RTE_ANS=/root/dpdk-ans
RUN cd /root && \
    git clone https://github.com/opendp/dpdk-ans.git && \
    cd /root/dpdk-ans && \
    ./install_deps.sh && \
    cd ans && \
    make
#   ./build/ans -c 0x2 -n 1  -- -p 0x1 --config="(0,0,1)"

# Build iperf with DPDK support
# Creates iperf3 and dpdk_iperf3 executables
RUN cd /root && \
    git clone https://github.com/opendp/dpdk-iperf.git && \
    cd /root/dpdk-iperf && \
    make all

# Expose the default iperf3 server port
EXPOSE 5201

# entrypoint allows you to pass your arguments to the container at runtime
# very similar to a binary you would run. For example, in the following
# docker run -it <IMAGE> --help' is like running 'iperf3-dpdk --help'
ENTRYPOINT ["/root/dpdk-iperf/dpdk_iperf3"]
