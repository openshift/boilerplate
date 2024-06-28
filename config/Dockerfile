# This file is used to confirm that the imagestream is valid and working
# the below statement will always be replaced by the source in .ci-operator.yaml
FROM registry.ci.openshift.org/openshift/release:rhel-8-release-golang-1.22-openshift-4.17

# TODO: remove this COPY/RUN
COPY build_image.sh /build_image.sh
RUN /build_image.sh && rm /build_image.sh
