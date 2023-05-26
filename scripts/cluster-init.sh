#!/usr/bin/env bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NOCOLOR='\033[0m'
# TO-DO: Should I replace whaley with the container name?
export PS1="\[\e]0;\u@whaley: \w\a\]${debian_chroot:+($debian_chroot)}\u@whaley:\w\$ "

echo -e ${GREEN}
echo "> Building the cluster"
echo -e ${NOCOLOR}
bash -c '/usr/local/bin/kind create cluster --image kindest/node:v1.25.2 --config /root/kind.yml'

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
MASTER_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' whaley-control-plane)
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
/bin/bash

# Delete the cluster at the end
echo -e ${CYAN}
echo "> Use kind delete cluster --name whaley to delete the cluster"
echo -e ${NOCOLOR}
