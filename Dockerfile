FROM debian:12-slim
COPY Makefile .
RUN apt-get update \
 && apt-get install -y make \
 && make req \
 && rm Makefile \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /build
CMD ["make"]
