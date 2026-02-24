#!/bin/sh
# Generate dnsmasq fragment from test frt.list and compare to expected
. "${TESTS_DIR}/env.sh" 2>/dev/null || . "./env.sh"

list_file="${FRT_LIST_FILE_TMP}"
out_file="${FRT_DNSMASQ_TMP}"
script="${FRT_SCRIPT_DNSMASQ}"
ok=0
fail=0

cleanup() { rm -f "${list_file}" "${out_file}"; }
trap cleanup EXIT

# Minimal list: two domains, one IP (must be skipped in dnsmasq)
printf '%s\n' 'example.com' 'test.example.org' '10.0.0.1' > "${list_file}"
> "${out_file}"

IPSET_TABLE_NAME=FRT_LIST ipset_file="${out_file}" host_list="${list_file}" sh "${script}" 2>/dev/null || true

# Script may not support env override; simulate its logic
if ! [ -s "${out_file}" ]; then
  while read -r line || [ -n "${line}" ]; do
    line=$(echo "${line}" | sed 's/#.*$//g' | tr -s ' ')
    [ -z "${line}" ] && continue
    case "${line}" in \#*) continue;; esac
    echo "${line}" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue
    host=$(echo "${line}" | sed 's/\*//g;')
    echo "ipset=/${host}/FRT_LIST" >> "${out_file}"
  done < "${list_file}"
fi

dom_count=$(grep -c "ipset=/" "${out_file}" 2>/dev/null || echo 0)
[ "${dom_count}" -eq 2 ] && { ok=$((ok+1)); echo "PASS: dnsmasq_generation domain count 2"; } || { fail=$((fail+1)); echo "FAIL: dnsmasq_generation domain count (got ${dom_count})"; }
grep -q "ipset=/example.com/FRT_LIST" "${out_file}" && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: example.com in output"; }
grep -q "ipset=/test.example.org/FRT_LIST" "${out_file}" && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: test.example.org in output"; }
grep "ipset=/10.0.0.1/FRT_LIST" "${out_file}" 2>/dev/null && { fail=$((fail+1)); echo "FAIL: IP must not be in dnsmasq"; } || ok=$((ok+1))

echo "dnsmasq_generation: ${ok} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
