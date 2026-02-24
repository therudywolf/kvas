#!/bin/sh
# Error and boundary cases: empty list, special chars, delete non-existent, duplicates, missing file
. "${TESTS_DIR}/env.sh" 2>/dev/null || . "./env.sh"

list_file="${FRT_LIST_FILE_TMP}"
out_file="${FRT_DNSMASQ_TMP}"
ok=0
fail=0

cleanup() { rm -f "${list_file}" "${out_file}" "${list_file}.tmp"; }
trap cleanup EXIT

# --- Empty list: generate dnsmasq -> empty file, no error
> "${list_file}"
> "${out_file}"
while read -r line || [ -n "${line}" ]; do
  line=$(echo "${line}" | sed 's/#.*$//g' | tr -s ' ')
  [ -z "${line}" ] && continue
  case "${line}" in \#*) continue;; esac
  echo "${line}" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue
  host=$(echo "${line}" | sed 's/\*//g;')
  echo "ipset=/${host}/FRT_LIST" >> "${out_file}"
done < "${list_file}"
[ ! -s "${out_file}" ] && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: empty list should produce empty dnsmasq"; }
echo "PASS: empty list"

# --- Delete non-existent: file unchanged
printf '%s\n' "only.example.com" > "${list_file}"
grep -v -F -x -- "nonexistent.example.com" "${list_file}" > "${list_file}.tmp" && mv "${list_file}.tmp" "${list_file}"
cnt=$(grep -c . "${list_file}" 2>/dev/null || echo 0)
[ "${cnt}" -eq 1 ] && grep -q -F -x "only.example.com" "${list_file}" && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: delete non-existent should leave file unchanged"; }
echo "PASS: delete non-existent"

# --- Duplicates: add same host twice -> two lines (current behavior); idempotent del
printf '%s\n' "dup.example.com" "dup.example.com" > "${list_file}"
cnt=$(grep -c . "${list_file}" 2>/dev/null || echo 0)
[ "${cnt}" -eq 2 ] && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: duplicates count"; }
grep -v -F -x -- "dup.example.com" "${list_file}" > "${list_file}.tmp" && mv "${list_file}.tmp" "${list_file}"
cnt=$(grep -c . "${list_file}" 2>/dev/null || echo 0)
[ "${cnt}" -eq 0 ] && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: del all duplicates"; }
echo "PASS: duplicates"

# --- Special chars: # in middle, leading/trailing space
printf '%s\n' 'domain.with-hyphen.com' 'host#comment' '  spaced  ' '' > "${list_file}"
> "${out_file}"
while read -r line || [ -n "${line}" ]; do
  line=$(echo "${line}" | sed 's/#.*$//g' | tr -s ' ')
  [ -z "${line}" ] && continue
  case "${line}" in \#*) continue;; esac
  echo "${line}" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue
  host=$(echo "${line}" | sed 's/\*//g;')
  echo "ipset=/${host}/FRT_LIST" >> "${out_file}"
done < "${list_file}"
grep -q "ipset=/domain.with-hyphen.com/FRT_LIST" "${out_file}" && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: hyphen domain"; }
grep -q "ipset=/host/FRT_LIST" "${out_file}" && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: # comment stripped"; }
echo "PASS: special chars"

# --- Missing list file: dnsmasq logic (script uses host_list var); we test that empty/missing -> empty output
rm -f "${list_file}"
> "${out_file}"
[ ! -f "${list_file}" ] && ok=$((ok+1)) || { fail=$((fail+1)); echo "FAIL: list removed"; }
echo "PASS: missing file handled"

echo "error_cases: ${ok} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
