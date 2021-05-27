# NOTE: Keep this in sync with .ci-operator.yaml
FROM registry.ci.openshift.org/openshift/boilerplate:image-v2.0.0

COPY build.sh /build.sh
RUN /build.sh && rm -f /build.sh
