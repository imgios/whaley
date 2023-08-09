# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Detect custom cluster configuration file (they must be named `kind.yaml` or `kind.yml`) in `/.whaley/config` to customize `kind` cluster creation using an already made configuration file:

```shell
whaley@docker:~$ docker run --name k8s-local-dev --rm \
-p 30303:8001 \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /home/imgios/kind.yml:/.whaley/config/kind.yml \
-it whaley:dev
```

- OpenContainers labels about the author, the source code and the image description.

## [1.2.1] - 2023/08/07

### Added

- Let the user define control-plane nodes using `--masters` option. By default, one control-plane will be created.
- Let the user define worker nodes using `-w|--workers` options. By default, two worker nodes will be created.
- Let the user define the cluster name using `--name` option. By default, its name is `whaley`.

### Changed

- whaley workdir changed from `/root/` to `/.whaley/`

### Removed

- The cluster won't be deleted anymore when closing (`exit`) the bash on the jumphost.

## From 1.0 to 1.2 - 2023/03

I'm sorry, I wasn't planning any release for the project, that's why I started writing down the following file only after those versions were created 😞.

[unreleased]: https://github.com/imgios/whaley/compare/main...dev
[1.2.1]: https://github.com/imgios/whaley/releases/tag/1.2.1
