# macOS Multipass Docker

Step by step notes for installing Docker under macOS via Canonical's [Multipass](https://canonical.com/multipass).

- [What this provides](#what-this-provides)
- [Installation](#installation)
- [Tips](#tips)
	- [Disable primary instance](#disable-primary-instance)
	- [Restarting `multipassd`](#restarting-multipassd)
- [Reference](#reference)

## What this provides

- Docker Engine (daemon).
- `docker` CLI tool within the guest VM (_technically_ not needed, but handy if working inside VM).
- Installed `docker` and `docker-compose` CLI tools (with Bash completion) on the macOS _host_.

## Installation

Install [Multipass for macOS](https://documentation.ubuntu.com/multipass/en/latest/how-to-guides/install-multipass/) (obviously).

Next, launch a new Multipass virtual machine.

> [!NOTE]
> Setting desired Multipass virtual machine name in `MACHINE_NAME` environment variable, used in all following command examples.

```sh
$ MACHINE_NAME="my-docker"
$ PATH_TO_PROJECTS="/path/to/projects"

$ multipass launch \
  --cloud-init ./cloud-init-docker.yaml \
  --name $MACHINE_NAME \
    24.04

$ multipass stop $MACHINE_NAME
$ multipass mount --type native \
  $PATH_TO_PROJECTS $MACHINE_NAME

$ multipass start $MACHINE_NAME
$ multipass info $MACHINE_NAME

# Name:           MACHINE_NAME
# State:          Running
# Snapshots:      0
# IPv4:           --

# Release:        Ubuntu 24.04.2 LTS
# Image hash:     bbecbb88100e (Ubuntu 24.04 LTS)
# CPU(s):         --
# Load:           --
# Disk usage:     --
# Memory usage:   --
# Mounts:         /path/to/projects => /home/ubuntu/projects
```

Breaking this down:

- Create new virtual machine using Ubuntu `24.04`.
- Configure VM using `cloud-init-docker.yaml` - which will install and configure Docker dependencies.
- Stop the instance in order to create a mount to (`path/to/projects`) within the VM _guest_ back to the macOS _host_. This is important for `Dockerfile` operations such as [`ADD`](https://docs.docker.com/reference/dockerfile/#add) - ensuring Docker Engine within the VM guest can successfully map files stored within the macOS host filesystem.
	- **Note:** using `multipass mount --type native` to create a native QEMU host mount, rather than the (slower) default of [SSHFS](https://github.com/libfuse/sshfs).

Overview of tasks performed by [`cloud-init-docker.yaml`](cloud-init-docker.yaml):

- The `avahi-daemon` provides a well-known hostname to the Multipass VM via mDNS/Bonjour from the host (e.g. your macOS).
- A series of `runcmd` commands to install required Docker Engine packages.
- An addition of a `/etc/systemd/system/docker.service.d/httpapi.conf` systemd unit drop-in, which starts the `/usr/bin/dockerd` daemon with the HTTP API listening on all networks.

Next, install `docker` and `docker-compose` CLI tools to the macOS _host_ via [`cli-install.sh`](cli-install.sh).

**Note:** script requires [`jq`](https://jqlang.org/) to be installed:

```sh
$ ./cli-install.sh

# Docker version 28.3.2, build 578ccf6
# Docker Compose version v2.38.2
```

Finally, configure a `DOCKER_HOST` environment variable, allowing the `docker` CLI to locate Docker Engine running within the Multipass Ubuntu VM:

```sh
# first, ping VM to confirm it can be found from host
$ dns-sd -Gv4 "$MACHINE_NAME.local"

$ export DOCKER_HOST="tcp://$MACHINE_NAME.local:2375"
$ docker version

# Client:
#  Version:           28.3.2
#  API version:       1.51
#  etc.
#
# Server: Docker Engine - Community
#  Engine:
#   Version:          28.3.2
#   API version:      1.51 (minimum version 1.24)
#  etc.
```

Once proven working, `DOCKER_HOST` can be added to Dotfiles / `~/.bash_profile` / etc.

Done!

## Tips

### Disable primary instance

Multipass has the concept of a [primary instance](https://documentation.ubuntu.com/multipass/en/latest/how-to-guides/manage-instances/use-the-primary-instance/), which is automatically used for commands such as `start` and `shell`. This behaviour can be somewhat _undesirable_ - where it is preferred to use defined machine names against all `multipass` commands.

The primary instance mode can be disabled by setting an empty [`client.primary-name`](https://documentation.ubuntu.com/multipass/en/latest/reference/settings/client-primary-name/) value:

```sh
$ multipass set client.primary-name=
```

the enablement of this mode can now be confirmed:

```sh
$ multipass start
Name argument or --all is required
Note: the primary instance is disabled.

$ multipass shell
The primary instance is disabled, please provide an instance name.
```

### Restarting `multipassd`

If the Multipass service ever falls away, such as with the following message:

```sh
$ multipass list
list failed: cannot connect to the multipass socket
```

it can be restarted with the following commands:

```sh
$ sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist
$ sudo launchctl load -w /Library/LaunchDaemons/com.canonical.multipassd.plist
```

## Reference

- https://documentation.ubuntu.com/multipass/en/latest/how-to-guides/install-multipass/
- https://ubuntu.com/blog/using-cloud-init-with-multipass
- https://docs.docker.com/engine/install/ubuntu/
- https://cloudinit.readthedocs.io/en/latest/reference/examples.html
- https://github.com/canonical/multipass/issues/2387
