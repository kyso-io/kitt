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
 bash-completion\
 ca-certificates\
 curl\
 git\
 gnupg\
 jq\
 lsb-release\
 nvi\
 sudo\
 unzip\
 && mkdir -p /etc/apt/keyrings\
 && curl -fsSL https://download.docker.com/linux/debian/gpg\
 | gpg --dearmor -o /etc/apt/keyrings/docker.gpg\
 && arch=$(dpkg --print-architecture)\
 && echo "deb [arch=$(dpkg --print-architecture)"\
 "signed-by=/etc/apt/keyrings/docker.gpg]"\
 "https://download.docker.com/linux/debian $(lsb_release -cs) stable"\
 | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null\
 && apt-get update\
 && apt-get install -y --no-install-recommends docker-ce-cli\
 && apt-get clean\
 && rm -rf /var/lib/apt/lists/*\
 && KITT_NONINTERACTIVE=true /usr/local/bin/kitt.sh tools apps
CMD ["/bin/bash"]
