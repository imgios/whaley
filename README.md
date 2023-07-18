# 🐋 whaley

Kubernetes-in-Docker ([`kind`](https://kind.sigs.k8s.io/)) project to run a small local Kubernetes cluster using Docker container nodes for several purposes:

1. Learn Docker & Kubernetes concepts
2. Test environment for work-in-progress Helm Charts (depending on the size)
3. Many others!

### Prerequisites

Just [`🐳 docker`](https://www.docker.com/)

(Optional) If you want to make some changes and/or build it manually:
```shell
docker build . -t <image-tag>
```

Run a docker container (replace the docker image name if you built it manually):
```shell
docker run --rm -p 30303:8001 -v /var/run/docker.sock:/var/run/docker.sock -it imgios/whaley:latest
```

This will boot up a Kubernetes cluster with a control-plane and two workers, and will also create to a jump-host server. If you want to update the node count, update [kind.yml](kind.yml):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: whaley
nodes:
- role: control-plane
- role: worker
- role: worker
```

## Built With

* [Docker](https://docs.docker.com/) - Platform as a Service (PaaS)
* [kind](https://kind.sigs.k8s.io/) - Tool for running local Kubernetes clusters using Docker container “nodes”
* [Kubernetes Dashboard](https://github.com/kubernetes/dashboard) - General-purpose web UI for Kubernetes clusters

## Contributing

Please read [CONTRIBUTING.md](#) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [docker image tags](https://github.com/imgios/whaley/pkgs/container/whaley).
