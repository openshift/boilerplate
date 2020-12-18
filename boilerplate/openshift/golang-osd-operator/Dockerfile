FROM quay.io/app-sre/boilerplate:image-v0.3.0 AS builder

ARG OPERATOR_NAME
ENV OPERATOR_NAME=$OPERATOR_NAME
ARG OPERATOR_DESCRIPTION
ENV OPERATOR_DESCRIPTION=$OPERATOR_DESCRIPTION

RUN mkdir -p /workdir
WORKDIR /workdir

# TODO: Can we get rid of this? Shouldn't it be part of `make go-build`?
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN make go-build

####
FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

ENV USER_UID=1001 \
    USER_NAME=${OPERATOR_NAME}

COPY --from=builder /workdir/build/_output/bin/* /usr/local/bin/

COPY build/bin /usr/local/bin
RUN  /usr/local/bin/user_setup

ENTRYPOINT ["/usr/local/bin/entrypoint"]

USER ${USER_UID}

LABEL io.openshift.managed.name="${OPERATOR_NAME}" \
      io.openshift.managed.description="${OPERATOR_DESCRIPTION}"
