# This file is used to confirm that the imagestream is valid and working
# the below statement will always be replaced by the source in .ci-operator.yaml
FROM registry.ci.openshift.org/openshift/release:rhel-8-release-golang-1.21-openshift-4.16

# TODO: remove this COPY/RUN
COPY build_image-v5.0.0.sh /build.sh
RUN /build.sh && rm /build.sh
