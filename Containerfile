ARG BASE_IMAGE=quay.io/fedora-ostree-desktops/silverblue
ARG BASE_TAG=44
FROM ${BASE_IMAGE}:${BASE_TAG}

# Slimbook hardware support
RUN --mount=type=secret,id=mok_priv \
    --mount=type=secret,id=mok_der <<-EOF
    set -euxo pipefail
    dnf upgrade -y \
        kernel kernel-core kernel-modules \
        kernel-modules-core kernel-modules-extra
    dnf config-manager addrepo \
        --from-repofile=https://download.opensuse.org/repositories/home:/Slimbook/Fedora_43/home:Slimbook.repo
    dnf install -y akmods kernel-devel-matched
    dnf install -y --setopt=tsflags=noscripts --setopt=install_weak_deps=False \
        slimbook-meta-common \
        slimbook-meta-executive \
        slimbook-meta-gnome \
        slimbook-service \
        slimbook-yt6801-kmod \
        slimbook-yt6801-kmod-common
    chmod 1777 /tmp
    mkdir -p /var/lib/akmods
    chown akmods:akmods /var/lib/akmods
    KVER=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}')
    ARCH=$(uname -m)
    SRPM=$(ls /usr/src/akmods/slimbook-yt6801-kmod-*.src.rpm)
    su -s /bin/bash akmods -c \
"cd /var/lib/akmods && HOME=/var/lib/akmods akmodsbuild --target ${ARCH} --kernels ${KVER} ${SRPM}"
    dnf install -y /var/lib/akmods/kmod-slimbook-yt6801-*.rpm
    # Sign the kmod with the MOK key
    mkdir -p /tmp/keys
    base64 -d /run/secrets/mok_priv > /tmp/keys/mok.priv
    base64 -d /run/secrets/mok_der  > /tmp/keys/mok.der
    chmod 600 /tmp/keys/mok.priv
    KO=$(find /usr/lib/modules/${KVER}/extra -name 'yt6801.ko*' | head -1)
    if [[ "${KO}" == *.xz ]]; then
        xz -d "${KO}"
        KO="${KO%.xz}"
    fi
    /usr/src/kernels/${KVER}/scripts/sign-file \
        sha256 /tmp/keys/mok.priv /tmp/keys/mok.der "${KO}"
    # Recompress signed module to save image space
    xz -T0 "${KO}"
    rm -rf /tmp/keys
    depmod -a "${KVER}"
    echo "yt6801" > /etc/modules-load.d/yt6801.conf
    dnf remove -y kernel-devel kernel-devel-matched akmods
    dnf clean all
EOF

# Keyd remap
COPY config/keyd/default.conf /etc/keyd/default.conf
RUN <<-EOF
    set -euxo pipefail
    dnf copr enable -y alternateved/keyd
    dnf install -y --setopt=install_weak_deps=False keyd
    systemctl enable keyd
    dnf clean all
EOF

# YubiKey GPG smart card
RUN <<-EOF
    set -euxo pipefail
    mkdir -p /etc/systemd/system/pcscd.service.d
    cat > /etc/systemd/system/pcscd.service.d/no-auto-exit.conf <<'CONF'
[Service]
ExecStart=
ExecStart=/usr/bin/pcscd --foreground
CONF
    systemctl enable pcscd.socket
EOF

# YubiKey FIDO2 PAM auth
RUN <<-EOF
	set -eux
	dnf install -y pam-u2f pamu2fcfg
	dnf clean all
EOF

# Tailscale VPN
RUN <<-EOF
    set -euxo pipefail
    dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
    dnf install -y --setopt=install_weak_deps=False tailscale
    systemctl enable tailscaled
    dnf clean all
EOF

# Tor service
RUN <<-EOF
	set -euxo pipefail
	dnf install -y --setopt=install_weak_deps=False tor

	printf 'd /var/lib/tor 0700 toranon toranon - -\nd /var/log/tor 0700 toranon toranon - -\n' > /usr/lib/tmpfiles.d/tor-bootc.conf

	systemctl enable tor
	dnf clean all
EOF

# Distrobox
RUN <<-EOF
    set -euxo pipefail
    dnf install -y --setopt=install_weak_deps=False distrobox
    dnf clean all
EOF

# Branding
ARG SLIMBOOK_DIGEST=unknown
RUN <<-EOF
    set -euxo pipefail
    SLIMBOOK_SHORT=$(echo "${SLIMBOOK_DIGEST}" | cut -c1-12)
    sed -i \
        -e 's/^NAME=.*/NAME="Silverblue Slimbook Executive"/' \
        -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Silverblue Slimbook Executive (Slimbook ${SLIMBOOK_SHORT})\"/" \
        -e 's/^VARIANT_ID=.*/VARIANT_ID=silverblue-slimbook-executive/' \
        -e 's|^HOME_URL=.*|HOME_URL="https://github.com/killianprovin/silverblue-slimbook"|' \
        /usr/lib/os-release
EOF

RUN ostree container commit
