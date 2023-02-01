FROM eclipse-temurin:11-jre-focal

ENV ALPACA_VERSION="2.2.0"
ENV ALPACA_LOG_LEVEL="INFO"
ENV ALPACA_HEAP="512m"
ENV ACTIVEMQ_HOST="activemq"
ENV ACTIVEMQ_JMS_PORT="61616"
ENV HOMARUS_URL="http://crayfish/homarus/convert"
ENV HOUDINI_URL="http://crayfish/houdini/convert"
ENV HYPERCUBE_URL="http://crayfish/hypercube"

RUN useradd alpaca

ADD --chown=alpaca:alpaca \
  https://repo1.maven.org/maven2/ca/islandora/alpaca/islandora-alpaca-app/${ALPACA_VERSION}/islandora-alpaca-app-${ALPACA_VERSION}-all.jar \
  /opt/alpaca/islandora-alpaca-app-all.jar

COPY --chown=alpaca:alpaca \
  alpaca.properties /opt/alpaca
USER alpaca

WORKDIR /opt/alpaca

CMD java -Dislandora.alpaca.log=${ALPACA_LOG_LEVEL} \
    -Djms.brokerUrl=tcp://${ACTIVEMQ_HOST}:${ACTIVEMQ_JMS_PORT} \
    -Dderivative.homarus.service.url=${HOMARUS_URL} \
    -Dderivative.houdini.service.url=${HOUDINI_URL} \
    -Dderivative.ocr.service.url=${HYPERCUBE_URL} \
    -Xmx${ALPACA_HEAP} \
    -jar /opt/alpaca/islandora-alpaca-app-all.jar \
    -c /opt/alpaca/alpaca.properties
