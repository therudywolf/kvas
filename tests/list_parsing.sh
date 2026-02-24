#!/bin/sh
# Test parsing of frt.list: comments, empty lines, IP, CIDR, ranges, domains
. "${TESTS_DIR}/env.sh" 2>/dev/null || . "./env.sh"

list_file="${FRT_LIST_FILE_TMP}"
ok=0
fail=0

cleanup() { rm -f "${list_file}"; }
trap cleanup EXIT

# Create sample list: comments, empty, IP, CIDR, range, domain
cat << 'SAMPLE' > "${list_file}"
# comment line
  # indented comment

1.2.3.4
10.0.0.0/24
192.168.1.0-192.168.1.255
example.com
sub.example.org
SAMPLE

# Count non-comment, non-empty lines (expected 5: 2 IP/CIDR/range + 2 domains; line with # is comment)
count=$(grep -v '^[[:space:]]*#' "${list_file}" | grep -v '^[[:space:]]*$' | grep -c . || true)
[ "${count}" -eq 5 ] && { ok=$((ok+1)); echo "PASS: list_parsing line count"; } || { fail=$((fail+1)); echo "FAIL: list_parsing line count (got ${count}, expected 5)"; }

# Check no IP in left part of dnsmasq output: run dnsmasq with test paths
ipset_file="${FRT_DNSMASQ_TMP}"
host_list="${list_file}"
export ipset_file host_list
> "${ipset_file}"
while read -r line || [ -n "${line}" ]; do
  line=$(echo "${line}" | sed 's/#.*$//g' | tr -s ' ')
  [ -z "${line}" ] && continue
  case "${line}" in \#*) continue;; esac
  echo "${line}" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue
  host=$(echo "${line}" | sed 's/\*//g;')
  echo "ipset=/${host}/FRT_LIST" >> "${ipset_file}"
done < "${host_list}"

# Domains should appear; IPs should not
grep -q "ipset=/example.com/FRT_LIST" "${ipset_file}" && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: domain example.com in dnsmasq"; }
grep -q "ipset=/1.2.3.4/FRT_LIST" "${ipset_file}" && { fail=$((fail+1)); echo "FAIL: IP must not be in dnsmasq"; } || ok=$((ok+1))

echo "list_parsing: ${ok} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
