FROM eclipse-temurin:11.0.27_6-jre-focal

# renovate: datasource=maven depName=alpaca packageName=ca.islandora.alpaca:islandora-alpaca-app
ENV ALPACA_VERSION=2.2.0
ENV ALPACA_LOG_LEVEL="INFO"
ENV JAVE_MEMORY="-Xms512m -Xmx512m"
ENV ACTIVEMQ_HOST="activemq"
ENV ACTIVEMQ_JMS_PORT="61616"
ENV HOMARUS_URL="http://crayfish/homarus/convert"
ENV HOUDINI_URL="http://crayfish/houdini/convert"
ENV HYPERCUBE_URL="http://crayfish/hypercube"
ENV CONCURRENT_CONSUMERS="1"

RUN useradd alpaca

ADD --chown=alpaca:alpaca \
  https://repo1.maven.org/maven2/ca/islandora/alpaca/islandora-alpaca-app/${ALPACA_VERSION}/islandora-alpaca-app-${ALPACA_VERSION}-all.jar \
  /opt/alpaca/islandora-alpaca-app-all.jar

COPY --chown=alpaca:alpaca \
  alpaca.properties /opt/alpaca

# renovate: datasource=github-release-attachments depName=prometheus/jmx_exporter
ARG JMX_EXPORTER_VERSION=1.4.0
ARG JMX_EXPORTER_DIGEST=sha256:db1492e95a7ee95cd5e0a969875c0d4f0ef6413148d750351a41cc71d775f59a
WORKDIR /jmx
ADD \
  --link \
  --chmod=644 \
  --checksum=$JMX_EXPORTER_DIGEST \
  https://github.com/prometheus/jmx_exporter/releases/download/$JMX_EXPORTER_VERSION/jmx_prometheus_javaagent-$JMX_EXPORTER_VERSION.jar jmx_prometheus_javaagent.jar
COPY --chmod=644 jmx.yml ./

USER alpaca

WORKDIR /opt/alpaca

CMD java -Dislandora.alpaca.log=${ALPACA_LOG_LEVEL} \
    -Djms.brokerUrl=tcp://${ACTIVEMQ_HOST}:${ACTIVEMQ_JMS_PORT} \
    -Dderivative.homarus.service.url=${HOMARUS_URL} \
    -Dderivative.houdini.service.url=${HOUDINI_URL} \
    -Dderivative.ocr.service.url=${HYPERCUBE_URL} \
    -Dderivative.homarus.concurrent-consumers=${CONCURRENT_CONSUMERS} \
    -Dderivative.houdini.concurrent-consumers=${CONCURRENT_CONSUMERS} \
    -Dderivative.ocr.concurrent-consumers=${CONCURRENT_CONSUMERS} \
    $JAVE_MEMORY \
    -javaagent:/jmx/jmx_prometheus_javaagent.jar=3001:/jmx/jmx.yml \
    -jar /opt/alpaca/islandora-alpaca-app-all.jar \
    -c /opt/alpaca/alpaca.properties
