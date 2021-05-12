# NOTE: Keep this in sync with .ci-operator.yaml
FROM registry.ci.openshift.org/openshift/boilerplate:image-v0.5.2

COPY build.sh /build.sh
RUN /build.sh && rm -f /build.sh
