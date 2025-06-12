FROM registry.access.redhat.com/ubi9/ubi-minimal:9.5-1742914212

ENV OPERATOR=/usr/local/bin/file-generate \
    USER_UID=1001 \
    USER_NAME=file-generate

# install operator binary
COPY build/_output/bin/file-generate ${OPERATOR}

COPY build/bin /usr/local/bin
RUN  /usr/local/bin/user_setup

ENTRYPOINT ["/usr/local/bin/entrypoint"]

USER ${USER_UID}
