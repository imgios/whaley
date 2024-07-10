#!/usr/bin/env bash

MASTERS=1
WORKERS=2
NAME=whaley
_config=/.whaley/kind.yml
INGRESS=false

error() {
  # This function prints error messages
  #
  # $1 is the message to display

  local message=''
  if [[ -z $1 ]]; then
    message="Something went wrong!"
  else
    message="$1"
  fi
  local timestamp=$(date +"%m-%d-%yT%T")
  printf "[ %s ] - ERROR - %s\n" "$timestamp" "$message" >&2
}

info() {
  # This function prints info messages
  #
  # $1 is the message to display

  local message=''
  if [[ -z $1 ]]; then
    message="Hello! The author forgot to add the message."
  else
    message="$1"
  fi
  local timestamp=$(date +"%m-%d-%yT%T")
  printf "[ %s ] - INFO - %s\n" "$timestamp" "$message"
}

debug() {
  # This function prints debug messages
  # if verbosity has been set to true.
  #
  # $1 is the message to display

  # Check if user enabled verbosity
  if [ "$VERBOSE" = false ]; then
    return 0 # do nothing
  fi

  local message=''
  if [[ -z $1 ]]; then
    message="Hello! The author forgot to add the message."
  else
    message="$1"
  fi
  local timestamp=$(date +"%m-%d-%yT%T")
  printf "[ %s ] - DEBUG - %s\n" "$timestamp" "$message"
}

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
    info "User cluster config file detected! The following configuration will be used:"
    echo
    cat $_config
elif [[ -e "/.whaley/config/kind.yaml" ]]; then
    _config=/.whaley/config/kind.yaml
    info "User cluster config file detected! The following configuration will be used:"
    echo
    cat $_config
fi

echo -e "\U0001F40B Building the cluster"
/usr/local/bin/kind create cluster --image kindest/node:v1.29.2 --config ${_config} || exit 1

# Retrieve docker container id
# Docker >= 1.12 - $HOSTNAME seems to be the short container id
if ! docker ps | grep -q $HOSTNAME; then
    error "Unable to retrieve the container id."
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
        error "There was an error while deploying the NGINX Ingress Controller. Skipping it."
        # exit 1
    fi
fi

echo
echo -e "\U0001F4CA Deploying the Kubernetes Dashboard"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
# TO-DO: Create self-signed certificates for the dashboard
[[ $INGRESS ]] && kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  namespace: kubernetes-dashboard
  name: kubernetes-dashboard-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  tls:
  - hosts:
    - dashboard.kind.local
    secretName: kubernetes-dashboard-cert
  rules:
  - host: dashboard.whaley.local
    http:
      paths:
      - path: /
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 443
EOF

echo
echo -e "\U0001F5DD  Creating the RBAC to access the Dashboard"
kubectl create serviceaccount k8s-dashboard-admin-sa
kubectl create clusterrolebinding k8s-dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:k8s-dashboard-admin-sa

if ! $INGRESS ; then
    echo
    echo -e "\U0001F310 Setting up the dashboard proxy"
    CLIENT_IP=$(docker inspect --format='{{.NetworkSettings.Networks.kind.IPAddress}}' $HOSTNAME)
    kubectl proxy --address=$CLIENT_IP --accept-hosts=^localhost$,^127\.0\.0\.1$,^\[::1\]$ &
    info "You can access the dashboard from there: http://127.0.0.1:30303/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
fi

# Start up a bash shell to try out Kubernetes
cd
echo
echo -e "\U00002139  Execute the following command if you want to destroy the cluster:"
echo "      kind delete cluster --name ${NAME}"
/bin/bash
