FROM ubuntu:latest

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y \
      bcc \
      build-essential \
      coreutils \
      curl \
      git \
      hexedit \
      make \
      nasm \
      tar \
      unzip \
      xxd \
      zip && \  
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*