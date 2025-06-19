FROM docker.io/eclipse-temurin:21-jre

ARG MINECRAFT_VERSION=1.21.6
ARG FABRIC_VERSION=0.16.14
ARG FABRIC_INSTALLER_VERSION=1.0.3

ENV RCON_PASSWORD=minecraft

EXPOSE 25565/tcp

RUN groupadd -r minecraft --gid=1337 && \
    useradd -r -g minecraft --uid=1337 --home-dir=/data --shell=/bin/bash minecraft

COPY --from=docker.io/itzg/rcon-cli:latest /rcon-cli /usr/local/bin/rcon-cli

RUN mkdir -p /app /data && \
    chmod 755 /app && \
    chown -R minecraft:minecraft /data

VOLUME /data
WORKDIR /data

ADD "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${FABRIC_VERSION}/${FABRIC_INSTALLER_VERSION}/server/jar" /app/server.jar
RUN chmod 644 /app/server.jar

COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh && \
    chown minecraft:minecraft /app/docker-entrypoint.sh

USER minecraft

ENTRYPOINT ["/app/docker-entrypoint.sh"]
