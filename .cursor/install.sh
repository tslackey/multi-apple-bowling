#!/usr/bin/env bash
#
# Cloud Agent environment bootstrap for "Multi Platform Bowling".
#
# NOTE: This is an Apple-platform Xcode app (SwiftUI + RealityKit + Core Motion)
# targeting iOS / macOS / tvOS. It can only be *built and run* with Xcode on
# macOS. Those Apple frameworks are closed-source and are not available on
# Linux, so this script installs the open-source Swift toolchain instead. That
# gives the agent a working Swift compiler, package manager, and language server
# for editing and syntax-checking Swift code on Linux.
#
# The script is idempotent: it can be run repeatedly and will skip work that is
# already complete.

set -euo pipefail

SWIFTLY_ENV="${HOME}/.local/share/swiftly/env.sh"

install_system_deps() {
    echo "==> Installing Swift runtime system dependencies"
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends \
        gnupg2 \
        curl \
        ca-certificates \
        libcurl4-openssl-dev \
        libpython3-dev \
        libxml2-dev \
        libncurses-dev \
        libz3-dev
}

install_swift() {
    if [ -f "${SWIFTLY_ENV}" ] && "${HOME}/.local/share/swiftly/bin/swiftly" --version >/dev/null 2>&1; then
        echo "==> swiftly already installed; ensuring a toolchain is present"
        # shellcheck disable=SC1090
        . "${SWIFTLY_ENV}"
        if ! swift --version >/dev/null 2>&1; then
            swiftly install latest --use --assume-yes
        fi
        return
    fi

    echo "==> Installing Swift toolchain via swiftly"
    local arch tmp
    arch="$(uname -m)"
    tmp="$(mktemp -d)"
    curl -fsSL -o "${tmp}/swiftly.tar.gz" \
        "https://download.swift.org/swiftly/linux/swiftly-${arch}.tar.gz"
    tar -xzf "${tmp}/swiftly.tar.gz" -C "${tmp}"
    "${tmp}/swiftly" init --assume-yes --quiet-shell-followup
    rm -rf "${tmp}"
}

main() {
    install_system_deps
    install_swift

    # shellcheck disable=SC1090
    . "${SWIFTLY_ENV}"
    hash -r

    echo "==> Swift toolchain ready:"
    swift --version
}

main "$@"
