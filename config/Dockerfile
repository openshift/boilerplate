# NOTE: Keep this in sync with .ci-operator.yaml
FROM registry.ci.openshift.org/openshift/release:golang-1.16

COPY build.sh /build.sh
RUN /build.sh && rm -f /build.sh
