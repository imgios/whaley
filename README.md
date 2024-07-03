# 🐋 whaley

Kubernetes-in-Docker ([`kind`](https://kind.sigs.k8s.io/)) project to run a small local Kubernetes cluster using Docker container nodes for several purposes:

1. Learn Docker & Kubernetes concepts
2. Test environment for work-in-progress Helm Charts (depending on the size)
3. Many others!

### Prerequisites

Just [`🐳 docker`](https://www.docker.com/)

Run a docker container:
```shell
docker run --rm [-p 30303:8001] -v /var/run/docker.sock:/var/run/docker.sock -it ghcr.io/imgios/whaley:latest [OPTIONS]
```

| Option           | Default value | Description                                              |
|:----------------:|:-------------:|----------------------------------------------------------|
| `--name`         | `whaley`      | Define the `kind` cluster name, e.g. `--name imgios`     |
| `-w, --workers`  | `2`           | Define the worker nodes count, e.g. `--workers 3`        |
| `--masters`      | `1`           | Define the control-plane nodes count, e.g. `--masters 2` |
| `--enable-ingress` | `false` | Enable the ingress support and deploy the Nginx Ingress Controller. It's a boolean flag, do not provide any value to it. |

If you run it without options, it will boot up a Kubernetes cluster named `whaley` with a control-plane and two workers. If you want to update the node count or the cluster name, you can easily use the options described before.

## Built With

* [Docker](https://docs.docker.com/) - Platform as a Service (PaaS)
* [kind](https://kind.sigs.k8s.io/) - Tool for running local Kubernetes clusters using Docker container “nodes”
* [Kubernetes Dashboard](https://github.com/kubernetes/dashboard) - General-purpose web UI for Kubernetes clusters

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [docker image tags](https://github.com/imgios/whaley/pkgs/container/whaley).
