FROM java:8-jdk

RUN apt-get update && apt-get install -y git curl zip && rm -rf /var/lib/apt/lists/*

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.6}
ENV JENKINS_SHA ${JENKINS_SHA:-0c47582a44e73c4bcc2b1a67756503111ccd4b81}
ENV JENKINS_UC https://updates.jenkins.io
ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log
ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888
ENV DOCKER_BUCKET get.docker.com
ENV DOCKER_VERSION 1.11.1
ENV DOCKER_SHA256 893e3c6e89c0cd2c5f1e51ea41bc2dd97f5e791fcfa3cee28445df277836339d

ARG JENKINS_VERSION
ARG JENKINS_SHA
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN groupadd -g ${gid} ${group} && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

VOLUME /var/jenkins_home

RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha1sum -c -

RUN curl -fsSL "https://raw.githubusercontent.com/jenkinsci/docker/373c45a59fbaa2b15e77408425205b158352480e/init.groovy" -o /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

RUN curl -fsSL http://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA  /usr/share/jenkins/jenkins.war" | sha1sum -c -

RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref


# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

RUN curl -fSL "https://raw.githubusercontent.com/jenkinsci/docker/373c45a59fbaa2b15e77408425205b158352480e/jenkins.sh" -o /usr/local/bin/jenkins.sh && chmod a+x /usr/local/bin/jenkins.sh

RUN curl -fsSL https://raw.githubusercontent.com/jenkinsci/docker/373c45a59fbaa2b15e77408425205b158352480e/plugins.sh -o /usr/local/bin/plugins.sh && chmod a+x /usr/local/bin/plugins.sh

RUN set -x \
	&& curl -fSL "https://${DOCKER_BUCKET}/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz" -o docker.tgz \
	&& echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
	&& tar -xzvf docker.tgz \
	&& mv docker/* /usr/local/bin/ \
	&& rmdir docker \
	&& rm docker.tgz \
	&& docker -v

RUN curl -fSL "https://raw.githubusercontent.com/docker-library/docker/f7ee50684c7ec92ce885c8b93a4ed22ddbb660f8/1.11/docker-entrypoint.sh" -o /usr/local/bin/docker-entrypoint.sh && chmod a+x /usr/local/bin/docker-entrypoint.sh

USER ${user}


ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

