# NOTE: Keep this in sync with .ci-operator.yaml
# TODO: Ratchet this up to start FROM boilerplate:image-v2.0.0
FROM registry.ci.openshift.org/openshift/release:golang-1.16

COPY build_image-v2.0.0.sh /build.sh
RUN /build.sh && rm -f /build.sh

COPY build.sh /build.sh
RUN /build.sh && rm -f /build.sh
