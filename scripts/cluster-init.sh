#!/usr/bin/env bash

GREEN='\033[0;32m'
NOCOLOR='\033[0m'
# TO-DO: Should I replace local-kind with the container name?
export PS1="\[\e]0;\u@local-kind: \w\a\]${debian_chroot:+($debian_chroot)}\u@local-kind:\w\$ "

echo -e ${GREEN}
echo "> Building the cluster"
echo -e ${NOCOLOR}
bash -c '/usr/local/bin/kind create cluster --image kindest/node:v1.25.2 --config /root/kind.yml'

echo -e ${GREEN}
echo "> Modifying Kubernetes config to point to the master node"
MASTER_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' local-kind-control-plane)
sed -i "s/^    server:.*/    server: https:\/\/$MASTER_IP:6443/" $HOME/.kube/config
cd

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
# 'local-kind' in the next line is the main container name
CLIENT_IP=$(docker inspect --format='{{.NetworkSettings.Networks.bridge.IPAddress}}' local-kind)
kubectl proxy --address=$CLIENT_IP --accept-hosts=^localhost$,^127\.0\.0\.1$,^\[::1\]$ &
echo "You can access the dashboard from there: http://127.0.0.1:30303/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"

# Start up a bash shell to try out Kubernetes
cd
/bin/bash

# Delete the cluster at the end
echo -e ${GREEN}
echo "> Destroying the cluster"
echo -e ${NOCOLOR}
kind delete cluster --name local-kind