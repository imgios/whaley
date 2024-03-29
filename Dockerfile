FROM alpine:3.17 as whaley
LABEL org.opencontainers.image.authors="@imgios"
LABEL org.opencontainers.image.source="https://github.com/imgios/whaley"
LABEL org.opencontainers.image.description="Kubernetes-in-Docker (kind) project to run a small local Kubernetes cluster using Docker container nodes."

RUN apk add --no-cache \
    bash \
    curl \
    docker \
    git \
    jq \
    openssl \
    sed \
    shadow \
    vim \
    wget

# Add Limited user
RUN groupadd -r whaley \
             -g 777 && \
    useradd -c "whaley init-script account" \
            -g whaley \
            -u 777 \
            -m \
            -r \
            whaley && \
    usermod -aG docker whaley

# Install kubectl
RUN curl -LO https://dl.k8s.io/release/v1.29.2/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# Install Kubernetes in Docker (kind)
RUN curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.22.0/kind-linux-amd64 && \
    chmod +x ./kind && \
    mv ./kind /usr/local/bin/kind

# Install helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh

ADD scripts /.whaley/scripts

COPY kind.yml /.whaley/

ENV PATH="${PATH}:/.whaley"

ENTRYPOINT ["/bin/bash", "/.whaley/scripts/cluster-init.sh"]
