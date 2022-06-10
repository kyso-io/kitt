# Base image to run the kitt.sh tool based on debian
ARG DEBIAN_VERSION=fixme
FROM registry.kyso.io/docker/debian:${DEBIAN_VERSION}
LABEL maintainer="Sergio Talens-Oliag <sto@kyso.io>"
# Update & install packages
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
 && echo "[KITT]" >/etc/debian_chroot
# Copy minimal kitt files to install applications
COPY bin/kitt.sh /usr/local/bin/kitt.sh
COPY lib/kitt/cmnd/tools /usr/local/lib/kitt/cmnd/
COPY lib/kitt/incl/common/io.sh /usr/local/lib/kitt/incl/common/
COPY lib/kitt/incl/tools.sh /usr/local/lib/kitt/incl/
# Install applications using kitt
RUN mkdir /usr/local/lib/kitt/tmpl\
 && KITT_NONINTERACTIVE=true /usr/local/bin/kitt.sh tools apps
# Add the entrypoint
COPY container/entrypoint.sh /entrypoint.sh
# Use our entrypoint (executes bash if no CMD is passed)
ENTRYPOINT ["/entrypoint.sh"]
