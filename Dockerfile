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
ARG VER="22.04"

ARG JMX_VER="1.5.0"
# ARG JMX_KEYS="https://populate-this-when-we-can"
ARG JMX_SRC="https://github.com/prometheus/jmx_exporter/releases/download/${JMX_VER}/jmx_prometheus_javaagent-${JMX_VER}.jar"

ARG CW_VER="1.8.0"
ARG CW_SRC="com.armedia.acm:curator-wrapper:${CW_VER}:jar:exe"
ARG CW_REPO="https://nexus.armedia.com/repository/arkcase"

ARG BC_GROUP="org.bouncycastle"

ARG BC_PKIX_GROUP="${BC_GROUP}"
ARG BC_PKIX="bcpkix-fips"
ARG BC_PKIX_VER="2.0.10"
ARG BC_PKIX_SRC="${BC_PKIX_GROUP}:${BC_PKIX}:${BC_PKIX_VER}:jar"

ARG BC_PROV_GROUP="${BC_GROUP}"
ARG BC_PROV="bc-fips"
ARG BC_PROV_VER="2.0.1"
ARG BC_PROV_SRC="${BC_PROV_GROUP}:${BC_PROV}:${BC_PROV_VER}:jar"

ARG BC_TLS_GROUP="${BC_GROUP}"
ARG BC_TLS="bctls-fips"
ARG BC_TLS_VER="2.0.22"
ARG BC_TLS_SRC="${BC_TLS_GROUP}:${BC_TLS}:${BC_TLS_VER}:jar"

ARG BC_UTIL_GROUP="${BC_GROUP}"
ARG BC_UTIL="bcutil-fips"
ARG BC_UTIL_VER="2.0.5"
ARG BC_UTIL_SRC="${BC_UTIL_GROUP}:${BC_UTIL}:${BC_UTIL_VER}:jar"

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
ARG JMX_KEYS
ARG JMX_SRC
ARG CW_SRC
ARG CW_REPO
ARG BC_PKIX
ARG BC_PKIX_SRC
ARG BC_PROV
ARG BC_PROV_SRC
ARG BC_TLS
ARG BC_TLS_SRC
ARG BC_UTIL
ARG BC_UTIL_SRC

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="ArkCase Base Java Image" \
      VERSION="${VER}"

ARG VER

# ARG CACERTS="/etc/pki/java/cacerts"
ARG CACERTS="/etc/ssl/certs/java/cacerts"

ENV TEMP="${TEMP_DIR}"
ENV TMP="${TEMP}"

#
# Add the JVMs
#
RUN wget -O - https://apt.corretto.aws/corretto.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/corretto-keyring.gpg && \
    chmod a+r /etc/apt/trusted.gpg.d/corretto-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/corretto-keyring.gpg] https://apt.corretto.aws stable main" | tee /etc/apt/sources.list.d/corretto.list && \
    apt-get update

RUN apt-get -y install \
        java-11-amazon-corretto-jdk \
        openjdk-17-jdk \
        openjdk-21-jdk \
      && \
    apt-get clean

#
# This is an important fix to ensure that all installed JVMs
# have their default cacerts file replaced with a link to
# the OS-provided cacerts file
#
RUN find /usr/lib/jvm -type f -name cacerts | \
    while read file ; do \
        ln -v "${file}" "${file}.orig" && \
        rm -vf "${file}" && \
        ln -vs "${CACERTS}" "${file}" ; \
    done

# Set the Java-centric envvars to paths that will be
# manipulated via the alternatives mechanism, so they
# always point to the correct location in the filesystem
ENV JAVA_HOME="/usr/lib/jvm/java"
ENV JRE_HOME="/usr/lib/jvm/jre"

#
# Add the JVM selector script
#
COPY --chown=root:root --chmod=0755 set-java set-java.* get-java fix-jars verified-download /usr/local/bin
COPY --chown=root:root --chmod=0640 01-set-java /etc/sudoers.d
RUN sed -i -e "s;\${ACM_GROUP};${ACM_GROUP};g" /etc/sudoers.d/01-set-java

#
# Add the common-use JMX agent JAR
#
ENV LIB_DIR="${BASE_DIR}/lib"
ENV JMX_AGENT_JAR="${LIB_DIR}/jmx-prometheus-agent.jar"
ENV JMX_AGENT_CONF="${CONF_DIR}/jmx-prometheus-agent.yaml"
ENV JMX_AGENT_ARG="-javaagent:${JMX_AGENT_JAR}=9100:${JMX_AGENT_CONF}"

COPY --chown=root:root --chmod=0755 jmx-prometheus-agent.yaml "${CONF_DIR}"
RUN mkdir -p "${LIB_DIR}" && \
    verified-download --hash "sha256" "${JMX_SRC}" "${JMX_AGENT_JAR}"

RUN mvn-get "${CW_SRC}" "${CW_REPO}" "/usr/local/bin/curator-wrapper.jar"

#
# Add the BouncyCastle FIPS stuff
#
ENV CRYPTO_DIR="${BASE_DIR}/crypto"
ENV BC_DIR="${CRYPTO_DIR}/bc"
ENV BC_PKIX_JAR="${BC_DIR}/${BC_PKIX}.jar"
ENV BC_PROV_JAR="${BC_DIR}/${BC_PROV}.jar"
ENV BC_TLS_JAR="${BC_DIR}/${BC_TLS}.jar"
ENV BC_UTIL_JAR="${BC_DIR}/${BC_UTIL}.jar"
RUN mkdir -p "${CRYPTO_DIR}" && \
    mvn-get "${BC_PKIX_SRC}" "${BC_PKIX_JAR}" && \
    mvn-get "${BC_PROV_SRC}" "${BC_PROV_JAR}" && \
    mvn-get "${BC_TLS_SRC}" "${BC_TLS_JAR}" && \
    mvn-get "${BC_UTIL_SRC}" "${BC_UTIL_JAR}"

#
# Default to Java 11 (Amazon Coretto), for now
#
RUN /usr/local/bin/set-java 11

# STIG Remediations
COPY --chown=root:root stig/ /usr/share/stig/
RUN cd /usr/share/stig && ./run-all
