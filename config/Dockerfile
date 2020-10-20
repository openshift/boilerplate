# NOTE: Keep this in sync with .ci-operator.yaml
FROM registry.svc.ci.openshift.org/openshift/release:golang-1.13

COPY build.sh /build.sh
RUN /build.sh && rm -f /build.sh
