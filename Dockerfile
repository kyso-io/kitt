# Image to run the kitt.sh tool based on debian
ARG DEBIAN_VERSION=fixme
FROM registry.kyso.io/docker/debian:${DEBIAN_VERSION}
LABEL maintainer="Sergio Talens-Oliag <sto@kyso.io>"
# Install packages
COPY bin/kitt.sh /usr/local/bin/kitt.sh
COPY lib/kitt/ /usr/local/lib/kitt/
RUN apt-get update\
 && apt-get dist-upgrade -y\
 && apt-get install -y --no-install-recommends\
 ca-certificates\
 curl\
 git\
 sudo\
 zsh\
 unzip\
 && apt-get clean\
 && rm -rf /var/lib/apt/lists/*\
 && KITT_NONINTERACTIVE=true /usr/local/bin/kitt.sh tools\
 aws\
 eksctl\
 helm\
 jq\
 k3d\
 kubectl\
 kubectx\
 sops\
 velero
CMD ["/bin/bash"]
