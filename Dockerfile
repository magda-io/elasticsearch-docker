################################################################################
# Modified from: 
# https://github.com/elastic/elasticsearch-docker/blob/6.5.4/templates/Dockerfile.j2
################################################################################
# Build stage 0 `prep_es_files`:
# Extract elasticsearch artifact
# Install required plugins
# Set gid=0 and make group perms==owner perms
################################################################################
FROM openjdk:11-jre-buster AS prep_es_files

ENV ES_VERSION=6.5.4
ENV INGEST_PLUGINS="ingest-user-agent ingest-geoip"
ENV ES_DOWNLOAD_URL=https://artifacts.elastic.co/downloads/elasticsearch
ENV ES_TARBAL=${ES_DOWNLOAD_URL}/elasticsearch-oss-${ES_VERSION}.tar.gz
ENV ES_TARBALL_ASC=${ES_DOWNLOAD_URL}/elasticsearch-${ES_VERSION}.tar.gz.asc
ENV ES_GPG_KEY=46095ACC8548582C1A2699A9D27D666CD88E42B4

ENV PATH /usr/share/elasticsearch/bin:$PATH

RUN groupadd -g 1000 elasticsearch && \
    useradd -u 1000 -g 1000 -d /usr/share/elasticsearch elasticsearch

WORKDIR /usr/share/elasticsearch

RUN chown -R elasticsearch:0 . && \
    chmod -R g=u /usr/share/elasticsearch

USER 1000

# Download and extract defined ES version.
RUN curl -fsSL "$ES_TARBAL" | \
    tar zx --strip-components=1

RUN set -ex && for esdirs in config data logs; do \
        mkdir -p "$esdirs"; \
    done

RUN ls -l && set -ex && for esdirs in config data logs; do \
        mkdir -p "$esdirs"; \
    done

RUN for PLUGIN in ${INGEST_PLUGINS}; do \
      elasticsearch-plugin install --batch "$PLUGIN"; done

COPY --chown=1000:0 elasticsearch.yml log4j2.properties config/

USER 0

# Set gid to 0 for elasticsearch and make group permission similar to that of user
# This is needed, for example, for Openshift Open: https://docs.openshift.org/latest/creating_images/guidelines.html
# and allows ES to run with an uid
RUN chown -R elasticsearch:0 . && \
    chmod -R g=u /usr/share/elasticsearch

################################################################################
# Build stage 1 (the actual elasticsearch image):
# Copy elasticsearch from stage 0
# Add entrypoint
################################################################################

FROM openjdk:11-jre-buster

ENV ES_VERSION=6.5.4
ENV ELASTIC_CONTAINER true

RUN apt-get update && \
    apt-get install -y netcat && \ 
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/share/elasticsearch

RUN groupadd -g 1000 elasticsearch && \
    useradd -u 1000 -g 1000 -G 0 -d /usr/share/elasticsearch elasticsearch && \
    chmod 0775 /usr/share/elasticsearch && \
    chgrp 0 /usr/share/elasticsearch

COPY --from=prep_es_files --chown=1000:0 /usr/share/elasticsearch /usr/share/elasticsearch
ENV PATH /usr/share/elasticsearch/bin:$PATH

COPY --chown=1000:0 bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Openshift overrides USER and uses ones with randomly uid>1024 and gid=0
# Allow ENTRYPOINT (and ES) to run even with a different user
RUN chgrp 0 /usr/local/bin/docker-entrypoint.sh && \
    chmod g=u /etc/passwd && \
    chmod 0775 /usr/local/bin/docker-entrypoint.sh

EXPOSE 9200 9300

LABEL org.label-schema.schema-version="1.0" \
  org.label-schema.vendor="Elastic" \
  org.label-schema.name="elasticsearch" \
  org.label-schema.version="${ES_VERSION}" \
  org.label-schema.url="https://www.elastic.co/products/elasticsearch" \
  org.label-schema.vcs-url="https://github.com/elastic/elasticsearch-docker" \
  license="Apache-2.0"

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# Dummy overridable parameter parsed by entrypoint
CMD ["eswrapper"]