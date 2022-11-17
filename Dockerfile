FROM alpine:3.17 as local-kind

RUN apk add --no-cache \
    bash \
    curl \
    docker \
    git \
    jq \
    openssl \
    shadow \
    vim \
    wget

# Add Limited user
RUN groupadd -r localkind \
             -g 777 && \
    useradd -c "localkind init-script account" \
            -g localkind \
            -u 777 \
            -m \
            -r \
            localkind && \
    usermod -aG docker localkind

# Install kubectl
RUN curl -LO https://dl.k8s.io/release/v1.25.2/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# Install Kubernetes in Docker (kind)
RUN curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.17.0/kind-linux-amd64 && \
    chmod +x ./kind && \
    mv ./kind /usr/local/bin/kind

# Install helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh

ADD scripts /root/scripts

COPY kind.yml /root/

ENV PATH="${PATH}:/root"

ENTRYPOINT ["/bin/bash", "/root/scripts/cluster-init.sh"]
