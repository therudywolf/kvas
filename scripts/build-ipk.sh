#!/usr/bin/env bash
# Сборка пакета FRT в .ipk.
# Режимы: --quick (pack-only, без Docker/SDK), Docker, или Entware SDK (TOPDIR).
set -e

APP_NAME=frt
ENTWARE_REPO_URL="${ENTWARE_REPO_URL:-https://github.com/Entware/Entware.git}"
BUILD_PATH="${BUILD_PATH:-/build/entware}"
DOCKER_IMAGE="${DOCKER_IMAGE:-entware-build-env}"
OUTPUT_DIR="${OUTPUT_DIR:-./output}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build FRT .ipk package."
    echo ""
    echo "Options:"
    echo "  --quick       Pack-only: build .ipk from opt/ without Docker or SDK (fast)"
    echo "  --docker      Use Docker (default if no TOPDIR)"
    echo "  --sdk         Use existing Entware SDK (requires TOPDIR)"
    echo "  -o DIR        Output directory for .ipk (default: ./output)"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Environment:"
    echo "  TOPDIR        Path to Entware SDK root (for --sdk)"
    echo "  DOCKER_IMAGE  Docker image name (default: entware-build-env)"
    echo "  OUTPUT_DIR    Output directory (default: ./output)"
}

mode=""
while [ $# -gt 0 ]; do
    case "$1" in
        --quick|--pack-only) mode=quick ;;
        --docker) mode=docker ;;
        --sdk)    mode=sdk ;;
        -o)       OUTPUT_DIR="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

# Автовыбор режима: если задан TOPDIR и режим не указан — sdk
if [ -z "$mode" ]; then
    if [ -n "$TOPDIR" ] && [ -d "$TOPDIR" ]; then
        mode=sdk
    else
        mode=docker
    fi
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# Pack-only: build .ipk from opt/ without Docker/SDK (PKGARCH=all)
build_quick() {
    if ! command -v ar &>/dev/null; then
        echo "Error: 'ar' (binutils) required for pack-only build. Install binutils or use --docker/--sdk." >&2
        exit 1
    fi
    echo "Building .ipk (pack-only)..."
    local MAKEFILE="${REPO_ROOT}/Makefile"
    local PKG_VERSION PKG_RELEASE
    PKG_VERSION=$(grep -E '^PKG_VERSION:=' "$MAKEFILE" | sed 's/PKG_VERSION:=//' | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    PKG_RELEASE=$(grep -E '^PKG_RELEASE:=' "$MAKEFILE" | sed 's/PKG_RELEASE:=//' | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$PKG_VERSION" ] && PKG_VERSION="1.1.9_beta-10"
    [ -z "$PKG_RELEASE" ] && PKG_RELEASE="19"

    local BUILD_QUICK="${REPO_ROOT}/.build-quick-$$"
    trap "rm -rf '$BUILD_QUICK'" EXIT
    mkdir -p "${BUILD_QUICK}/data/opt/etc/init.d"
    mkdir -p "${BUILD_QUICK}/data/opt/etc/ndm/fs.d"
    mkdir -p "${BUILD_QUICK}/data/opt/etc/ndm/netfilter.d"
    mkdir -p "${BUILD_QUICK}/data/opt/apps/frt"

    cp "${REPO_ROOT}/opt/etc/ndm/fs.d/15-frt-start.sh" "${BUILD_QUICK}/data/opt/etc/ndm/fs.d/"
    cp "${REPO_ROOT}/opt/etc/ndm/netfilter.d/100-dns-local" "${BUILD_QUICK}/data/opt/etc/ndm/netfilter.d/"
    cp "${REPO_ROOT}/opt/etc/init.d/S96frt" "${BUILD_QUICK}/data/opt/etc/init.d/"
    cp -r "${REPO_ROOT}/opt/." "${BUILD_QUICK}/data/opt/apps/frt/"

    # Normalize line endings to LF in data (avoid opkg "Malformed" on router when built on Windows)
    find "${BUILD_QUICK}/data" -type f 2>/dev/null | while read -r f; do
        [ -f "$f" ] && sed 's/\r$//' "$f" > "${f}.nocr" 2>/dev/null && mv "${f}.nocr" "$f" || true
    done

    mkdir -p "${BUILD_QUICK}/control"
    cat > "${BUILD_QUICK}/control/control" << EOF
Package: ${APP_NAME}
Version: ${PKG_VERSION}-${PKG_RELEASE}
Architecture: all
Maintainer: Rudy Wolf
Description: Forest Router Tool (FRT). VPN/whitelist: traffic to listed hosts via VPN or Shadowsocks.
Depends: libpcre, jq, curl, knot-dig, nano-full, cron, bind-dig, dnsmasq-full, ipset, iptables, shadowsocks-libev-ss-redir, shadowsocks-libev-config, libmbedtls, stubby
EOF

    sed -e "s/@PKG_VERSION@/${PKG_VERSION}/g" -e "s/@PKG_RELEASE@/${PKG_RELEASE}/g" \
        "${REPO_ROOT}/scripts/postinst.in" | sed 's/\r$//' > "${BUILD_QUICK}/control/postinst"
    chmod +x "${BUILD_QUICK}/control/postinst"

    # debian-binary: exactly "2.0" + LF (no CRLF), required by opkg
    printf '%s\n' '2.0' > "${BUILD_QUICK}/debian-binary"
    # Strip CR from control file (Windows build can leave CRLF)
    sed 's/\r$//' "${BUILD_QUICK}/control/control" > "${BUILD_QUICK}/control/control.tmp" && mv "${BUILD_QUICK}/control/control.tmp" "${BUILD_QUICK}/control/control"

    ( cd "${BUILD_QUICK}/control" && tar --numeric-owner --owner=0 --group=0 -czf ../control.tar.gz . )
    ( cd "${BUILD_QUICK}/data" && tar --numeric-owner --owner=0 --group=0 -czf ../data.tar.gz . )
    ( cd "${BUILD_QUICK}" && ar rv "${OUTPUT_DIR}/${APP_NAME}_${PKG_VERSION}-${PKG_RELEASE}_all.ipk" debian-binary control.tar.gz data.tar.gz )
    echo "Done. .ipk is in: $OUTPUT_DIR"
}

build_via_docker() {
    echo "Building .ipk via Docker..."
    if ! command -v docker &>/dev/null; then
        echo "Error: docker not found." >&2
        exit 1
    fi
    # Собираем образ из репозитория (Dockerfile в builder/)
    if ! docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
        echo "Building Docker image: $DOCKER_IMAGE"
        docker build \
            --build-arg USER_NAME=master \
            --build-arg APP_PATH=/home/master/${APP_NAME} \
            --build-arg BUILDING_PATH=${BUILD_PATH} \
            -t "$DOCKER_IMAGE" \
            -f "$REPO_ROOT/builder/Dockerfile" \
            "$REPO_ROOT"
    fi
    # Монтируем: репо -> /home/master/frt, output -> /output, создаём build
    BUILD_VOLUME="${REPO_ROOT}/.build-$$"
    mkdir -p "$BUILD_VOLUME"
    trap "rm -rf '$BUILD_VOLUME'" EXIT
    docker run --rm \
        --mount "type=bind,source=${REPO_ROOT},target=/home/master/${APP_NAME}" \
        --mount "type=bind,source=${OUTPUT_DIR},target=/output" \
        --mount "type=bind,source=${BUILD_VOLUME},target=/build" \
        -e "OUTPUT_DIR=/output" \
        "$DOCKER_IMAGE" \
        bash -c "/home/master/${APP_NAME}/builder/builder all ${APP_NAME} ${BUILD_PATH} ${ENTWARE_REPO_URL}"
    echo "Done. .ipk is in: $OUTPUT_DIR"
}

build_via_sdk() {
    echo "Building .ipk via Entware SDK (TOPDIR=$TOPDIR)..."
    if [ -z "$TOPDIR" ] || [ ! -d "$TOPDIR" ]; then
        echo "Error: TOPDIR must be set and point to Entware SDK root." >&2
        exit 1
    fi
    TOPDIR="$(cd "$TOPDIR" && pwd)"
    if [ ! -f "$TOPDIR/rules.mk" ] || [ ! -d "$TOPDIR/scripts" ]; then
        echo "Error: TOPDIR does not look like Entware/OpenWrt root (rules.mk, scripts/)." >&2
        exit 1
    fi
    FEEDS_PACKAGES="${TOPDIR}/feeds/packages"
    FRT_FEED="${FEEDS_PACKAGES}/${APP_NAME}"
    mkdir -p "$FEEDS_PACKAGES"
    if [ -L "$FRT_FEED" ]; then
        rm -f "$FRT_FEED"
    fi
    ln -sf "$REPO_ROOT" "$FRT_FEED"
    ( cd "$TOPDIR" && scripts/feeds update packages "${APP_NAME}" && scripts/feeds install -a "${APP_NAME}" )
    ( cd "$TOPDIR" && make defconfig && make -j"${MAKE_JOBS:-$(nproc 2>/dev/null || echo 4)}" "package/${APP_NAME}/compile" )
    n=0
    for f in "${TOPDIR}"/bin/targets/*/*/packages/${APP_NAME}.*.ipk; do
        [ -f "$f" ] && cp "$f" "$OUTPUT_DIR/" && n=$((n+1))
    done
    if [ "$n" -eq 0 ]; then
        echo "Error: .ipk not found after build under $TOPDIR/bin/targets/..." >&2
        exit 1
    fi
    echo "Done. .ipk is in: $OUTPUT_DIR"
}

case "$mode" in
    quick) build_quick ;;
    docker) build_via_docker ;;
    sdk)   build_via_sdk ;;
    *)     echo "Invalid mode: $mode" >&2; exit 1 ;;
esac
