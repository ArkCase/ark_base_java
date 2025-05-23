###########################################################################################################
#
# How to build:
#
# docker build -t arkcase/core:latest .
#
# How to run: (Helm)
#
# helm repo add arkcase https://arkcase.github.io/ark_helm_charts/
# helm install core arkcase/core
# helm uninstall core
#
###########################################################################################################

#
# Basic Parameters
#
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="8"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base"
ARG BASE_VER="${VER}"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}:${BASE_VER_PFX}${BASE_VER}"

FROM "${BASE_IMG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="ArkCase Base Java Image" \
      VERSION="${VER}"

#
# Environment variables
#
ENV JAVA_HOME="/usr/lib/jvm/java" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

ARG VER

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

ENV TEMP="${BASE_DIR}/temp"
ENV TMP="${TEMP}"

#
# Add the JVMs
#
RUN yum -y install \
        https://corretto.aws/downloads/latest/amazon-corretto-11-x64-linux-jdk.rpm \
        java-17-openjdk-devel \
        java-21-openjdk-devel \
      && \
    yum -y clean all

# Set the Java-centric envvars to paths that will be
# manipulated via the alternatives mechanism, so they
# always point to the correct location in the filesystem
ENV JAVA_HOME="/usr/lib/jvm/java"
ENV JRE_HOME="/usr/lib/jvm/jre"

#
# Add the JVM selector script
#
COPY --chown=root:root set-java /usr/local/bin
RUN chmod 0755 /usr/local/bin/set-java

#
# Default to Java 11 (Amazon Coretto), for now
#
RUN /usr/local/bin/set-java 11
