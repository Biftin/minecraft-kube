FROM docker.io/eclipse-temurin:21-jre

ARG MINECRAFT_VERSION=1.21.6
ARG FABRIC_VERSION=0.16.14
ARG FABRIC_INSTALLER_VERSION=1.0.3

ADD "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${FABRIC_VERSION}/${FABRIC_INSTALLER_VERSION}/server/jar" /app/server.jar

COPY --from=docker.io/itzg/rcon-cli:latest /rcon-cli /usr/local/bin/rcon-cli

ENV RCON_PASSWORD=minecraft

EXPOSE 25565/tcp

VOLUME /data
WORKDIR /data

COPY docker-entrypoint.sh /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
