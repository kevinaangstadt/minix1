FROM ubuntu:latest

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y \
      bcc \
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