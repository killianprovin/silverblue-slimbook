# Silverblue Slimbook

[![Build](https://github.com/killianprovin/silverblue-slimbook/actions/workflows/build.yml/badge.svg)](https://github.com/killianprovin/silverblue-slimbook/actions/workflows/build.yml)

Custom [Fedora Silverblue](https://fedoraproject.org/silverblue/) image for the **Slimbook Executive 14** laptop.

## What's included

- **Slimbook hardware support** — `slimbook-service`, GNOME integration, and the `yt6801` Ethernet kernel module
- **[keyd](https://github.com/rvaiya/keyd)**
- **[Tailscale](https://tailscale.com/)**
- **YubiKey GPG**
- **[Distrobox](https://distrobox.it/)**

## Usage

Rebase an existing Silverblue install:

```bash
sudo bootc switch ghcr.io/killianprovin/silverblue-slimbook:stable
sudo systemctl reboot
```

## Building locally

```bash
podman build -t silverblue-slimbook \
  --secret=id=mok_priv,src=/path/to/mok.priv.b64 \
  --secret=id=mok_der,src=/path/to/mok.der.b64 \
  .
```