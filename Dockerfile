FROM debian:12-slim
RUN apt-get update \
 && apt-get install -y \
      make \
      gcc \
      gcc-arm-none-eabi \
      crossbuild-essential-arm64 \
      bison \
      flex \
      device-tree-compiler \
      swig \
      python3-dev \
      python3-pyelftools \
      python3-setuptools \
      libssl-dev \
      libgnutls28-dev \
      uuid-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /build
