#!/usr/bin/env bash

MASTERS=1
WORKERS=2
NAME=whaley
_config=/.whaley/kind.yml
EXTRA_PORT_MAPPING=false

# Parse options from the CLI
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
    -w | --workers )
        shift; [[ "$1" =~ ^[0-9]$ ]] && WORKERS=$1 || WORKERS=2
        ;;
    -m | --masters)
        shift; [[ "$1" =~ ^[0-9]$ ]] && MASTERS=$1 || MASTERS=1
        ;;
    --name)
        if [[ -n "$2" && ! "$2" =~ ^- && ! "$1" == "--" ]]; then
            shift; NAME=$1
            sed -i "s/whaley/$NAME/g" $_config
        fi
        ;;
    --extra-port-mapping )
        EXTRA_PORT_MAPPING=true
        ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

# Populate kind config file with both control-plane and workers nodes
for (( i = 0 ; i < $MASTERS; i++)); do
    echo "- role: control-plane" >> $_config
done
for (( i = 0 ; i < $WORKERS; i++)); do
    echo "- role: worker" >> $_config
done

# Enable port mapping on the first control-plane container
if $EXTRA_PORT_MAPPING ; then
yq '(.nodes[] | select(.role == "control-plane") | select(key < 1)).kubeadmConfigPatches = ["kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: \"ingress-ready=true\""] ' kind.yaml | sed "s/- |-/- |/"
fi

GREEN='\033[0;32m'
NOCOLOR='\033[0m'
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
    

echo -e ${GREEN}
echo "> Building the cluster"
echo -e ${NOCOLOR}
/usr/local/bin/kind create cluster --image kindest/node:v1.29.2 --config ${_config} || exit 1

# Retrieve docker container id
# Docker >= 1.12 - $HOSTNAME seems to be the short container id
if ! docker ps | grep -q $HOSTNAME; then
    echo "[ERROR] - Unable to retrieve the container id."
    exit 1
fi

# Connect the  jump host node on the same net
docker network connect kind $HOSTNAME

echo -e ${GREEN}
echo "> Modifying Kubernetes config to point to the master node"
echo -e ${NOCOLOR}
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

echo -e ${GREEN}
echo "> Deploying the Kubernetes Dashboard"
echo -e ${NOCOLOR}
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

echo -e ${GREEN}
echo "> Creating the RBAC to access the Dashboard"
echo -e ${NOCOLOR}
kubectl create serviceaccount k8s-dashboard-admin-sa
kubectl create clusterrolebinding k8s-dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:k8s-dashboard-admin-sa

echo -e ${GREEN}
echo "> Setting up the dashboard proxy"
echo -e ${NOCOLOR}
# 'whaley' in the next line is the main container name
# TO-DO: Change whaley with the container name
CLIENT_IP=$(docker inspect --format='{{.NetworkSettings.Networks.kind.IPAddress}}' $HOSTNAME)
kubectl proxy --address=$CLIENT_IP --accept-hosts=^localhost$,^127\.0\.0\.1$,^\[::1\]$ &
echo "You can access the dashboard from there: http://127.0.0.1:30303/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"

# Start up a bash shell to try out Kubernetes
cd
echo
echo -e "\U2139 Execute the following command if you want to destroy the cluster:"
echo "      kind delete cluster --name ${NAME}"
/bin/bash
