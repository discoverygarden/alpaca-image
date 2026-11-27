FROM eclipse-temurin:17-jre-noble

# renovate: datasource=maven depName=alpaca packageName=ca.islandora.alpaca:islandora-alpaca-app
ENV ALPACA_VERSION=2.2.0
ENV ALPACA_LOG_LEVEL="INFO"
ENV JAVA_MEMORY="-Xms512m -Xmx512m"
ENV ACTIVEMQ_HOST="activemq"
ENV ACTIVEMQ_JMS_PORT="61616"
ENV HOMARUS_URL="http://crayfish/homarus/convert"
ENV HOUDINI_URL="http://crayfish/houdini/convert"
ENV HYPERCUBE_URL="http://crayfish/hypercube"
ENV CONCURRENT_CONSUMERS="1"
ENV REQUEST_CONFIGURER_ENABLED="false"
ENV REQUEST_TIMEOUT="-1"
ENV CONNECTION_TIMEOUT="-1"
ENV SOCKET_TIMEOUT="-1"

RUN useradd alpaca

ADD --chown=alpaca:alpaca \
  https://repo1.maven.org/maven2/ca/islandora/alpaca/islandora-alpaca-app/${ALPACA_VERSION}/islandora-alpaca-app-${ALPACA_VERSION}-all.jar \
  /opt/alpaca/islandora-alpaca-app-all.jar

COPY --chown=alpaca:alpaca \
  alpaca.properties /opt/alpaca

# renovate: datasource=github-release-attachments depName=prometheus/jmx_exporter
ARG JMX_EXPORTER_VERSION=1.7.0
ARG JMX_EXPORTER_DIGEST=sha256:0ad843261c567d1924a017d542e14c40f2afff523d940c25ee000742fde4b3a9
WORKDIR /jmx
ADD \
  --link \
  --chmod=644 \
  --checksum=$JMX_EXPORTER_DIGEST \
  https://github.com/prometheus/jmx_exporter/releases/download/$JMX_EXPORTER_VERSION/jmx_prometheus_javaagent-$JMX_EXPORTER_VERSION.jar jmx_prometheus_javaagent.jar
COPY --chmod=644 jmx.yml ./

USER alpaca

WORKDIR /opt/alpaca

COPY --chmod=755 <<"EOT" /entrypoint.sh
#!/usr/bin/env bash

set -x
exec java -Dislandora.alpaca.log=${ALPACA_LOG_LEVEL} \
  -Djms.brokerUrl=tcp://${ACTIVEMQ_HOST}:${ACTIVEMQ_JMS_PORT} \
  -Dderivative.homarus.service.url=${HOMARUS_URL} \
  -Dderivative.houdini.service.url=${HOUDINI_URL} \
  -Dderivative.ocr.service.url=${HYPERCUBE_URL} \
  -Dderivative.homarus.concurrent-consumers=${CONCURRENT_CONSUMERS} \
  -Dderivative.houdini.concurrent-consumers=${CONCURRENT_CONSUMERS} \
  -Dderivative.ocr.concurrent-consumers=${CONCURRENT_CONSUMERS} \
  -Drequest.configurer.enabled=${REQUEST_CONFIGURER_ENABLED} \
  -Drequest.timeout=${REQUEST_TIMEOUT} \
  -Dconnection.timeout=${CONNECTION_TIMEOUT} \
  -Dsocket.timeout=${SOCKET_TIMEOUT} \
  $JAVA_MEMORY \
  -javaagent:/jmx/jmx_prometheus_javaagent.jar=3001:/jmx/jmx.yml \
  -jar /opt/alpaca/islandora-alpaca-app-all.jar \
  -c /opt/alpaca/alpaca.properties
EOT

CMD ["/entrypoint.sh"]

# --------------------------------------
# Package manifest: prints every installed package to the build log as
#   DGI-PKG <arch> <type> <name> <version>
# so security checks can read versions from the image build's job log.
# Keep this as the last step of the final stage.
# --------------------------------------
RUN a=$(uname -m); \
  dpkg-query -W -f='${Package} ${Version}\n' | sed "s/^/DGI-PKG $a deb /"; \
  find / -xdev -name '*.jar' 2>/dev/null | sed "s/^/DGI-PKG $a jar /"; \
  j=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}; \
  [ -f "$j/release" ] && (. "$j/release"; echo "DGI-PKG $a jdk $j ${JAVA_RUNTIME_VERSION:-$JAVA_VERSION} $(echo "${IMPLEMENTOR_VERSION:-$IMPLEMENTOR}" | tr ' ' _)"); \
  true
