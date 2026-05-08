# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=quay.io/fedora-ostree-desktops/silverblue
ARG BASE_TAG=44

FROM ${BASE_IMAGE}:${BASE_TAG}

ARG SLIMBOOK_FEDORA=43
ARG SLIMBOOK_DIGEST=unknown
ENV SLIMBOOK_FEDORA=${SLIMBOOK_FEDORA} \
    SLIMBOOK_DIGEST=${SLIMBOOK_DIGEST}

# Slimbook hardware: yt6801 akmod build + MOK signing
RUN --mount=type=secret,id=mok_priv \
    --mount=type=secret,id=mok_der \
    --mount=type=cache,target=/var/cache/libdnf5,sharing=locked \
<<'EOF'
set -euxo pipefail
echo 'install_weak_deps=False' >> /etc/dnf/dnf.conf

dnf -y upgrade kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra

dnf -y config-manager addrepo \
    --from-repofile=https://download.opensuse.org/repositories/home:/Slimbook/Fedora_${SLIMBOOK_FEDORA}/home:Slimbook.repo

dnf -y install akmods kernel-devel-matched

# tsflags=noscripts skips the useradd %post that fails on read-only /etc
dnf -y install --setopt=tsflags=noscripts \
    slimbook-meta-common \
    slimbook-meta-executive \
    slimbook-meta-gnome \
    slimbook-service \
    slimbook-yt6801-kmod \
    slimbook-yt6801-kmod-common

chmod 1777 /tmp
install -d -o akmods -g akmods /var/lib/akmods

KVER=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -1)
ARCH=$(uname -m)
SRPM=$(ls /usr/src/akmods/slimbook-yt6801-kmod-*.src.rpm)
runuser -u akmods -- env HOME=/var/lib/akmods \
    akmodsbuild --target "${ARCH}" --kernels "${KVER}" "${SRPM}"
dnf -y install /var/lib/akmods/kmod-slimbook-yt6801-*.rpm

KO_XZ=$(find "/usr/lib/modules/${KVER}/extra" -name 'yt6801.ko.xz' -print -quit)
KO="${KO_XZ%.xz}"
xz -d --keep "${KO_XZ}"

install -d -m 700 /run/keys
base64 -d /run/secrets/mok_priv > /run/keys/mok.priv
base64 -d /run/secrets/mok_der  > /run/keys/mok.der
"/usr/src/kernels/${KVER}/scripts/sign-file" sha256 \
    /run/keys/mok.priv /run/keys/mok.der "${KO}"
shred -u /run/keys/mok.priv
rm -rf /run/keys

xz -T0 -f "${KO}"
test -f "${KO_XZ}"

depmod -a "${KVER}"
echo 'yt6801' > /etc/modules-load.d/yt6801.conf

dnf -y remove kernel-devel kernel-devel-matched akmods
EOF

# Userspace: keyd, YubiKey, Tailscale, Distrobox, GNOME extensions
COPY config/keyd/default.conf /etc/keyd/default.conf
RUN --mount=type=cache,target=/var/cache/libdnf5,sharing=locked \
<<'EOF'
set -euxo pipefail

dnf -y copr enable alternateved/keyd
dnf -y install keyd

dnf -y install \
    pam-u2f pamu2fcfg \
    distrobox \
    gnome-shell-extension-gsconnect \
    gnome-shell-extension-caffeine \
    gnome-shell-extension-blur-my-shell \
    gnome-shell-extension-dash-to-dock \
    gnome-shell-extension-just-perfection

dnf -y config-manager addrepo \
    --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf -y install tailscale

systemctl enable keyd tailscaled pcscd.socket

# pcscd no-auto-exit override for YubiKey GPG stability
install -d /etc/systemd/system/pcscd.service.d
cat > /etc/systemd/system/pcscd.service.d/no-auto-exit.conf <<'CONF'
[Service]
ExecStart=
ExecStart=/usr/bin/pcscd --foreground
CONF
EOF

# Branding + cleanup + commit
RUN <<'EOF'
set -euxo pipefail

SLIMBOOK_SHORT=$(echo "${SLIMBOOK_DIGEST}" | cut -c1-12)
sed -i \
    -e 's/^NAME=.*/NAME="Silverblue Slimbook Executive"/' \
    -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Silverblue Slimbook Executive (Slimbook ${SLIMBOOK_SHORT})\"/" \
    -e 's/^VARIANT_ID=.*/VARIANT_ID=silverblue-slimbook-executive/' \
    -e 's|^HOME_URL=.*|HOME_URL="https://github.com/killianprovin/silverblue-slimbook"|' \
    /usr/lib/os-release

dnf -y clean all
rm -rf /var/log/* /var/cache/* /var/tmp/*

bootc container lint || true
ostree container commit
EOF

LABEL containers.bootc=1 \
      ostree.bootable=1 \
      org.opencontainers.image.title="Silverblue Slimbook Executive" \
      org.opencontainers.image.source="https://github.com/killianprovin/silverblue-slimbook" \
      org.opencontainers.image.licenses="MIT"
