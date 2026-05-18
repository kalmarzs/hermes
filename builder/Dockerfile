FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    build-essential \
    devscripts \
    debhelper \
    dh-make \
    wget \
    curl \
    ca-certificates \
    fakeroot \
    unzip \
    docker.io \
    reprepro \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
#CMD ["tail", "-f", "/dev/null"]
