# Test environment for FRT (Forest Router Tool)
# Use temporary paths; do not touch /opt
export TESTS_DIR="${TESTS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
export FRT_LIST_FILE_TMP="${TESTS_DIR}/frt.list.test"
export FRT_DNSMASQ_TMP="${TESTS_DIR}/frt.dnsmasq.test"
export FRT_SCRIPT_DNSMASQ="${TESTS_DIR}/../opt/bin/main/dnsmasq"
export FRT_SCRIPT_IPSET="${TESTS_DIR}/../opt/bin/main/ipset"
# For list_parsing and dnsmasq_generation we override host_list/ipset_file via env when calling scripts
export PATH="${TESTS_DIR}/../opt/bin:${PATH}"
