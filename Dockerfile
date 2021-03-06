#
# Image for Isegoria dbinterface API and Neo4j graph database
#
FROM ubuntu:16.04
LABEL maintainer="Yikai Gong - yikaig@student.unimelb.edu.au"

ARG InstitutionName=Institution
ARG CampusName=Campus

ENV DEBIAN_FRONTEND=noninteractive
ENV NEO4J_VERSION=3.3.0

USER root
RUN apt-get update && apt-get install -y software-properties-common \
    openssh-client curl sudo vim net-tools locales python3-software-properties \
    tar unzip openjdk-8-jdk git maven awscli

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH ${PATH}:${JAVA_HOME}

# Setup local specific information for encoding
RUN locale-gen "en_AU.UTF-8"
ENV LANG="en_AU.UTF-8"
ENV LANGUAGE="en_AU:en"
ENV LC_ALL="en_AU.UTF-8"

## ====== Install Neo4j =========
ENV NEO4J_HOME=/opt/neo4j
ENV NEO4J_DATA_DIR=/mnt/data
RUN curl -s https://neo4j.com/artifact.php?name=neo4j-enterprise-${NEO4J_VERSION}-unix.tar.gz | tar -xz -C /opt && \
    ln -s /opt/neo4j-enterprise-${NEO4J_VERSION} ${NEO4J_HOME} && \
    mkdir -p ${NEO4J_DATA_DIR} && echo "dbms.directories.data=${NEO4J_DATA_DIR}" >> ${NEO4J_HOME}/conf/neo4j.conf
ENV PATH ${PATH}:${NEO4J_HOME}/bin

## ====== Install API =========
ADD binary/dbInterface-0.1.0.war /opt
ARG Neo4j_PWD=X8+Q4^9]1715q|W
ENV NEO4j_PWD=${Neo4j_PWD}
ENV INSTITUTION=${InstitutionName}
ENV CAMPUS=${CampusName}
ENV API_HOME=/opt/dbinterface
RUN mkdir -p ${API_HOME} && mv /opt/dbInterface-0.1.0.war ${API_HOME}
ADD config ${API_HOME}
RUN sed -i -e "s/^spring.data.neo4j.username=.*$/spring.data.neo4j.username=neo4j/g" ${API_HOME}/application.properties && \
    sed -i -e "s/^spring.data.neo4j.password=.*$/spring.data.neo4j.password=${Neo4j_PWD}/g" ${API_HOME}/application.properties

## ====== Install APOC for Neo4j =========
ADD binary/apoc-3.3.0.4-all.jar ${NEO4J_HOME}/plugins
RUN chmod +rx ${NEO4J_HOME}/plugins/*.jar
RUN echo "dbms.security.procedures.unrestricted=apoc.export.*,apoc.import.*" >> ${NEO4J_HOME}/conf/neo4j.conf && \
    echo "apoc.export.file.enabled=true" >> ${NEO4J_HOME}/conf/neo4j.conf && \
    echo "apoc.import.file.enabled=true" >> ${NEO4J_HOME}/conf/neo4j.conf

## ==================== Setup scripts ================================
ENV SCRIPT_BASE=/root
ADD script/startup.sh ${SCRIPT_BASE}
ADD script/backup_neo4j_to_s3.sh ${SCRIPT_BASE}
RUN chmod +x ${SCRIPT_BASE}/*.sh
ENV PATH ${PATH}:${SCRIPT_BASE}

ADD script/backup_neo4j_crontab /etc/cron.d/backup_neo4j
RUN chmod 0644 /etc/cron.d/backup_neo4j

ENTRYPOINT ["/root/startup.sh"]

EXPOSE 8080