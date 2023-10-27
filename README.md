# macOS Multipass Docker

Step by step notes for installing Docker under macOS via Canonical's [Multipass](https://multipass.run/).

- [What this provides](#what-this-provides)
- [Installation steps](#installation-steps)
- [Reference](#reference)

## What this provides

- Docker Engine (daemon).
- `docker` CLI tool within the guest VM (_technically_ not needed, but handy if working inside VM).
- Installed `docker` and `docker-compose` CLI tools (with Bash completion) on the macOS _host_.

## Installation steps

Install [Multipass for macOS](https://multipass.run/docs/installing-on-macos) (obviously).

Next, launch a new Multipass virtual machine.

**Note:** Setting the desired machine name in `MACHINE_NAME` environment variable for use in all following command examples:

```sh
$ MACHINE_NAME="my-docker"
$ PATH_TO_PROJECTS="/path/to/projects"

$ multipass launch \
  --cloud-init ./cloud-init-docker.yaml \
  --name $MACHINE_NAME \
    20.04

$ multipass stop $MACHINE_NAME
$ multipass mount --type native \
  $PATH_TO_PROJECTS $MACHINE_NAME

$ multipass start $MACHINE_NAME
$ multipass info $MACHINE_NAME

# Name:           MACHINE_NAME
# State:          Running
# IPv4:           --

# Release:        --
# Image hash:     e2e27e9b9a82 (Ubuntu 20.04 LTS)
# Load:           --
# Disk usage:     --
# Memory usage:   --
# Mounts:         /path/to/projects => /path/to/projects
```

Breaking this down:

- Create new virtual machine using Ubuntu `20.04`.
- Configure VM using `cloud-init-docker.yaml` - which will install and configure Docker dependencies.
- Stop the instance in order to create a mount to (`path/to/projects`) within the VM _guest_ back to the macOS _host_. This is important for `Dockerfile` operations such as [`ADD`](https://docs.docker.com/engine/reference/builder/#add) - ensuring Docker Engine within the VM guest can successfully map files stored within the macOS host filesystem.
	- **Note:** using `multipass mount --type native` to create a native QEMU host mount, rather than the (slower) default of [SSHFS](https://github.com/libfuse/sshfs).

Overview of [`cloud-init-docker.yaml`](cloud-init-docker.yaml) tasks:

- The `avahi-daemon` provides a well-known hostname for the Multipass VM via mDNS/Bonjour.
- A series of `runcmd` commands to install required Docker Engine packages.
- An addition of a `/etc/systemd/system/docker.service.d/httpapi.conf` systemd unit drop-in, which will start `/usr/bin/dockerd` with the HTTP API listening on all networks.

Next, install `docker` and `docker-compose` CLI tools to the macOS _host_ via [`cli-install.sh`](cli-install.sh).

**Note:** script requires [`jq`](https://jqlang.github.io/jq/) to be installed:

```sh
$ ./cli-install.sh

# Docker version 24.0.7, build afdd53b
# Docker Compose version v2.23.0
```

Finally, configure a `DOCKER_HOST` environment variable, allowing the `docker` CLI to locate Docker Engine running within the Multipass Ubuntu VM:

```sh
# first, ping VM to confirm it can be found from host
$ dns-sd -Gv4 "$MACHINE_NAME.local"

$ export DOCKER_HOST="tcp://$MACHINE_NAME.local:2375"
$ docker version

# Client:
#  Version:           24.0.7
#  API version:       1.43
#  etc.
#
# Server: Docker Engine - Community
#  Engine:
#   Version:          24.0.7
#   API version:      1.43 (minimum version 1.12)
#  etc.
```

Once proven working, `DOCKER_HOST` can be added to Dotfiles / `~/.bash_profile` / etc.

Done!

## Reference

- https://multipass.run/docs/installing-on-macos
- https://ubuntu.com/blog/using-cloud-init-with-multipass
- https://docs.docker.com/engine/install/ubuntu/
- https://cloudinit.readthedocs.io/en/latest/reference/examples.html
