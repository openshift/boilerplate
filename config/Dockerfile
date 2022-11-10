# NOTE: Keep this in sync with .ci-operator.yaml
# TODO: temporary until image is built, should be: FROM registry.ci.openshift.org/openshift/boilerplate:image-v3.0.0
FROM registry.ci.openshift.org/ocp/builder:rhel-8-golang-1.19-openshift-4.12

# TODO: remove this COPY/RUN
COPY build_image-v3.0.0.sh /build.sh
RUN /build.sh && rm /build.sh
