# Image to run the kitt.sh tool based on debian
ARG BASE_VERSION=fixme
FROM registry.kyso.io/kyso-io/kitt:${BASE_VERSION}
# Install latest versions of kitt
COPY bin/kitt.sh /usr/local/bin/kitt.sh
COPY lib/kitt/ /usr/local/lib/kitt/
COPY version.txt /usr/local/lib/kitt/incl/
