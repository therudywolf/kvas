#!/usr/bin/env bash
# Сборка пакета kvas в .ipk.
# Режимы: Docker (по умолчанию) или через существующий Entware SDK (TOPDIR).
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
    echo "Build kvas .ipk package."
    echo ""
    echo "Options:"
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
    # Монтируем: репо -> /home/master/kvas, output -> /output, создаём build
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
    KVAS_FEED="${FEEDS_PACKAGES}/${APP_NAME}"
    mkdir -p "$FEEDS_PACKAGES"
    if [ -L "$KVAS_FEED" ]; then
        rm -f "$KVAS_FEED"
    fi
    ln -sf "$REPO_ROOT" "$KVAS_FEED"
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
    docker) build_via_docker ;;
    sdk)   build_via_sdk ;;
    *)     echo "Invalid mode: $mode" >&2; exit 1 ;;
esac
