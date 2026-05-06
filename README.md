# Silverblue Slimbook

[![Build](https://github.com/killianprovin/silverblue-slimbook/actions/workflows/build.yml/badge.svg)](https://github.com/killianprovin/silverblue-slimbook/actions/workflows/build.yml)

Custom [Fedora Silverblue](https://fedoraproject.org/silverblue/) image for the **Slimbook Executive 14** laptop.

## What's included

- **Slimbook hardware support** — `slimbook-service`, GNOME integration, and the `yt6801` Ethernet kernel module (signed against the user's MOK key)
- **[keyd](https://github.com/rvaiya/keyd)** — key remapping daemon
- **YubiKey** — GPG smart card support (`pcscd`) and FIDO2 PAM authentication (`pam-u2f`)
- **[Tailscale](https://tailscale.com/)** — mesh VPN
- **[Tor](https://www.torproject.org/)** — onion routing service
- **[Distrobox](https://distrobox.it/)** — containerized dev environments
- **GNOME extensions** — GSConnect, Caffeine, Blur My Shell, Dash to Dock, Just Perfection, Clipboard Indicator

## Usage

Rebase an existing Silverblue install:

```bash
sudo bootc switch ghcr.io/killianprovin/silverblue-slimbook:stable
sudo systemctl reboot
```

## Building locally

The build requires a Machine Owner Key pair (base64-encoded) to sign the `yt6801` kernel module for Secure Boot:

```bash
podman build -t silverblue-slimbook \
  --secret=id=mok_priv,src=/path/to/mok.priv.b64 \
  --secret=id=mok_der,src=/path/to/mok.der.b64 \
  .
```
