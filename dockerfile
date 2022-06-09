FROM ubuntu:latest
RUN apt-get update && apt-get install make\
    && apt-get install -y sudo\ 
    && apt-get install -y wget \
    && apt-get -y install cmake\ 
    && sudo ls\
    && wget https://developer.download.nvidia.com/compute/cuda/11.7.0/local_installers/cuda_11.7.0_515.43.04_linux.run\
    && sudo ./cuda_11.7.0_515.43.04_linux.run
    && cd SC-22-MLSim/
    && make
WORKDIR /SC-22-MLSim/

