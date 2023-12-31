Deployment recipes available [here](./docs/deployment)

# Kyso Internal Tool of Tools

This repository contains a command line tool to deploy and develop the
different Kyso components.

The initial prototipe will be developed using shell scripts derived from the
existing code of `kyso-deploy` and `kyso-k3d`, but the plan is to rewrite
everything using a portable language like [Rust](https://rust-lang.org) or
[Go](https://go.dev/).

## Features

The tool will include support to do the following tasks:

- Install or upgrade tools on the user machine (things like `docker`, `helm`,
  `kubectl`, `k3d`, etc.).

- Manage configurations, secrets, git repositories, container images and
  packages from the [Kyso Gitlab Server](https://gitlab.kyso.io/).

- Run containers on the developer machine using
  [docker desktop](https://www.docker.com/products/docker-desktop/) (maybe in the
  future we can also add support for [podman](https://podman.io/) or other
  container execution system).

- Install [kubernetes](https://kubernetes.io/) clusters using [k3d](https://k3d.io)
  for development and testing (requires `docker` when running the cluster on
  the local machine)

- Deploy and configure third party applications on development (`k3d`) and
  production clusters (i. e. on AWS) using `helm` and `kubectl`, including
  things like `prometheus`, `grafana`, `loki`, `velero`, etc.

- Deploy `kyso` third party components (i.e. `mongodb`, `elasticsearch`, ...)
  and our own services (`kyso-api`, `kyso-scs`, `kyso-ui`, ...) on kubernetes
  clusters.

- Setup tunnels to run development versions of the `kyso-api` and/or `kyso-ui`
  tunnels against local or remote deployments of the `kyso` ecosystem.

- Perform common mainteinance tasks on the `kyso` deployments (backup and
  restore databases or filesystems, update components, etc.)