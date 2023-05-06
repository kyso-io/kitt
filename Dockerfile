ARG BASE_VERSION=fixme

# Documentation builder
FROM registry.kyso.io/docker/docker-asciidoctor AS doc-builder
WORKDIR /kitt
COPY . .
RUN sh ./sbin/build-docs.sh

# Image to run the kitt.sh tool based on debian
FROM registry.kyso.io/kyso-io/kitt:${BASE_VERSION}
# Install latest versions of kitt
COPY bin/kitt.sh /usr/local/bin/kitt.sh
COPY lib/kitt/ /usr/local/lib/kitt/
COPY version.txt /usr/local/lib/kitt/incl/
COPY --from=doc-builder /kitt/share/doc/kitt/ /usr/local/share/doc/kitt/
