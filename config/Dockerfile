FROM quay.io/konflux-ci/yq:latest as yq
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_8_1.22 AS builder

ARG GOCILINT_VERSION="1.59.1"
ARG GOCILINT_SHA256SUM="c30696f1292cff8778a495400745f0f9c0406a3f38d8bb12cef48d599f6c7791"
ARG GOCILINT_LOCATION=https://github.com/golangci/golangci-lint/releases/download/v${GOCILINT_VERSION}/golangci-lint-${GOCILINT_VERSION}-linux-amd64.tar.gz

RUN curl -L -o golangci-lint.tar.gz ${GOCILINT_LOCATION} && \
    echo ${GOCILINT_SHA256SUM} golangci-lint.tar.gz | sha256sum -c && \
    tar xzf golangci-lint.tar.gz golangci-lint-${GOCILINT_VERSION}-linux-amd64/golangci-lint && \
    mv golangci-lint-${GOCILINT_VERSION}-linux-amd64/golangci-lint /usr/local/bin

ARG GH_VERSION="2.58.0"
ARG GH_SHA256SUM="84feae3d143bc360ea1004b474f124c8cfd75363a5e197d3ce63fe23d9f3a2ea"
ARG GH_LOCATION=https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz

RUN curl -L -o gh.tar.gz ${GH_LOCATION} && \
    echo ${GH_SHA256SUM} gh.tar.gz | sha256sum -c && \
    tar xzf gh.tar.gz gh_${GH_VERSION}_linux_amd64/bin/gh && \
    mv gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin

FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_8_1.22
ENV GOFLAGS=-mod=mod

ARG KUSTOMIZE_VERSION="v5.4.1" \
    CONTROLLER_GEN_VERSION="v0.15.0" \
    OPENAPI_GEN_VERSION="v0.29.1" \
    ENVTEST_VERSION="release-0.18" \
    GOVULNCHECK_VERSION="v1.1.3" \
    MOCKGEN_VERSION="v0.4.0"

RUN go install sigs.k8s.io/kustomize/kustomize/v5@${KUSTOMIZE_VERSION} && \
    go install sigs.k8s.io/controller-tools/cmd/controller-gen@${CONTROLLER_GEN_VERSION} && \
    go install k8s.io/code-generator/cmd/openapi-gen@${OPENAPI_GEN_VERSION} && \
    go install sigs.k8s.io/controller-runtime/tools/setup-envtest@${ENVTEST_VERSION} && \
    go install golang.org/x/vuln/cmd/govulncheck@${GOVULNCHECK_VERSION} && \
    go install go.uber.org/mock/mockgen@${MOCKGEN_VERSION}

# HACK: `go install` creates lots of things under GOPATH that are not group
# accessible, even if umask is set properly. This causes failures of
# subsequent go tool usage (e.g. resolving packages) by a non-root user,
# which is what consumes this image in CI.
# Here we make group permissions match user permissions, since the CI
# non-root user's gid is 0.
SHELL ["/bin/bash", "-c"]
RUN for bit in r x w; do find $(go env GOPATH) -perm -u+${bit} -a ! -perm -g+${bit} -exec chmod g+${bit} '{}' +; done

COPY --from=builder /usr/local/bin/golangci-lint /usr/local/bin
COPY --from=builder /usr/local/bin/gh /usr/local/bin
COPY --from=yq /usr/bin/yq /usr/bin/yq

RUN dnf -y install openssh-clients jq skopeo python3-pyyaml && \
    dnf clean all && \
    dnf -y autoremove && \
    rm -rf /var/cach/dnf

COPY LICENSE /licenses/.
ENV PATH $PATH:/go/bin
