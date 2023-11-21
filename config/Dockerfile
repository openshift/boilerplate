# This file is used to confirm that the imagestream is valid and working
# the below statement will always be replaced by the source in .ci-operator.yaml
FROM REPLACEME

# TODO: remove this COPY/RUN
COPY build_image-v4.0.0.sh /build.sh
RUN /build.sh && rm /build.sh
