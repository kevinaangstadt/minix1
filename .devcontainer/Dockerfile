FROM ubuntu:latest

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y \
      build-essential \
      coreutils \
      curl \
      file \
      gcc-doc \
      git \
      gnupg2 \
      hexedit \
      man-db \
      make \
      nasm \
      tar \
      unminimize \
      unzip \
      xxd \
      zip && \  
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    yes | unminimize && \
    apt-get autoremove -y
  
RUN git clone https://github.com/lkundrak/dev86 /dev86 && \
    cd /dev86 && \
    git checkout v0.16.21 && \
    make && \
    make install && \
    rm -rf /dev86