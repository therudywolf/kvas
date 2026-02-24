#!/bin/sh
# Add/remove hosts in temporary frt.list and check file contents
. "${TESTS_DIR}/env.sh" 2>/dev/null || . "./env.sh"

list_file="${FRT_LIST_FILE_TMP}"
ok=0
fail=0

cleanup() { rm -f "${list_file}"; }
trap cleanup EXIT

# Start empty
> "${list_file}"

# Add: append one line
echo "host1.example.com" >> "${list_file}"
echo "host2.example.com" >> "${list_file}"
cnt=$(grep -c . "${list_file}" 2>/dev/null || echo 0)
[ "${cnt}" -eq 2 ] && { ok=$((ok+1)); echo "PASS: host_add_del add count"; } || { fail=$((fail+1)); echo "FAIL: add count (got ${cnt})"; }

# Remove one: one-pass grep -v -F -x
host_="host1.example.com"
grep -v -F -x -- "${host_}" "${list_file}" > "${list_file}.tmp" && mv "${list_file}.tmp" "${list_file}"
cnt=$(grep -c . "${list_file}" 2>/dev/null || echo 0)
[ "${cnt}" -eq 1 ] && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: after del count (got ${cnt})"; }
grep -q -F -x "host2.example.com" "${list_file}" && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: host2 still present"; }
grep -q -F -x "host1.example.com" "${list_file}" && { fail=$((fail+1)); echo "FAIL: host1 must be removed"; } || ok=$((ok+1))

echo "host_add_del: ${ok} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
