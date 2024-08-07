#!/usr/bin/env bash

MASTERS=1
WORKERS=2
NAME=whaley
_config=/.whaley/kind.yml
INGRESS=false

# Parse options from the CLI
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
    -w | --workers )
        shift; [[ "$1" =~ ^[0-9]$ ]] && WORKERS=$1 || WORKERS=2
        ;;
    -m | --masters)
        shift; [[ "$1" =~ ^[1-9]$ ]] && MASTERS=$1 || MASTERS=1
        ;;
    --name)
        if [[ -n "$2" && ! "$2" =~ ^- && ! "$1" == "--" ]]; then
            shift; NAME=$1
            sed -i "s/whaley/$NAME/g" $_config
        fi
        ;;
    --enable-ingress )
        INGRESS=true
        ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

# Always add a control-plane node
if $INGRESS ; then
    echo "- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: \"ingress-ready=true\"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP" >> $_config
else
    echo "- role: control-plane" >> $_config
fi

# Populate kind config file with both control-plane and workers nodes
for (( i = 1 ; i < $MASTERS; i++)); do
    echo "- role: control-plane" >> $_config
done
for (( i = 0 ; i < $WORKERS; i++)); do
    echo "- role: worker" >> $_config
done

# TO-DO: Should I replace whaley with the container name?
export PS1="\[\e]0;\u@${NAME}: \w\a\]${debian_chroot:+($debian_chroot)}\u@${NAME}:\w\$ "

# Check if kind.yml (or .yaml) has been mounted in /.whaley/config/kind.yml (or .yaml)
if [[ -e "/.whaley/config/kind.yml" ]]; then
    _config=/.whaley/config/kind.yml
    echo "INFO :: User cluster config file detected! The following configuration will be used:"
    echo
    cat $_config
elif [[ -e "/.whaley/config/kind.yaml" ]]; then
    _config=/.whaley/config/kind.yaml
    echo "INFO :: User cluster config file detected! The following configuration will be used:"
    echo
    cat $_config
fi

echo -e "\U0001F40B Building the cluster"
/usr/local/bin/kind create cluster --image kindest/node:v1.29.2 --config ${_config} || exit 1

# Retrieve docker container id
# Docker >= 1.12 - $HOSTNAME seems to be the short container id
if ! docker ps | grep -q $HOSTNAME; then
    echo "[ERROR] - Unable to retrieve the container id."
    exit 1
fi

# Connect the jump host node on the same net
docker network connect kind $HOSTNAME

echo
echo -e "\U0001F4C4 Modifying Kubernetes config to point to the master node"
MASTER_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${NAME}-control-plane)
sed -i "s/^    server:.*/    server: https:\/\/$MASTER_IP:6443/" $HOME/.kube/config
cd

# Issue: worker nodes are marked with role: none
# Not sure if the issue is related to this version or something wrong by me :)
# In case, they can be fixed on the fly adding a label
WORKER_NODES=$(kubectl get nodes --no-headers | grep -v control-plane | awk '{print $1}')
for worker in ${WORKER_NODES}; do
    kubectl label node ${worker} node-role.kubernetes.io/worker=worker
done

if $INGRESS ; then
    echo
    echo -e "\U0001F6AA Deploying the NGINX Ingress Controller"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    nginx_deploy=$?
    sleep 30s
    if [ $nginx_deploy -ne 0 ] || ! kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s ; then
        echo "There was an error while deploying the NGINX Ingress Controller."
        # exit 1
    fi
fi

echo
echo -e "\U0001F4CA Deploying the Kubernetes Dashboard"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

echo
echo -e "\U0001F5DD  Creating the RBAC to access the Dashboard"
kubectl create serviceaccount k8s-dashboard-admin-sa
kubectl create clusterrolebinding k8s-dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:k8s-dashboard-admin-sa

if ! $INGRESS ; then
    echo
    echo -e "\U0001F310 Setting up the dashboard proxy"
    # 'whaley' in the next line is the main container name
    # TO-DO: Change whaley with the container name
    CLIENT_IP=$(docker inspect --format='{{.NetworkSettings.Networks.kind.IPAddress}}' $HOSTNAME)
    kubectl proxy --address=$CLIENT_IP --accept-hosts=^localhost$,^127\.0\.0\.1$,^\[::1\]$ &
    echo "You can access the dashboard from there: http://127.0.0.1:30303/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
fi

# Start up a bash shell to try out Kubernetes
cd
echo
echo -e "\U00002139  Execute the following command if you want to destroy the cluster:"
echo "      kind delete cluster --name ${NAME}"
/bin/bash
