#!/bin/sh
# FRT test runner: run all test scripts, exit 0 if all pass, 1 otherwise
TESTS_DIR="${TESTS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
export TESTS_DIR

run_one() {
  name="$1"
  script="${TESTS_DIR}/${name}"
  if [ ! -f "${script}" ]; then
    echo "SKIP: ${name} (not found)"
    return 0
  fi
  if ( sh "${script}" ); then
    echo "OK: ${name}"
    return 0
  else
    echo "FAIL: ${name}"
    return 1
  fi
}

total=0
failed=0
for t in list_parsing.sh dnsmasq_generation.sh host_add_del.sh error_cases.sh; do
  total=$((total+1))
  run_one "${t}" || failed=$((failed+1))
done

echo "---"
if [ "${failed}" -eq 0 ]; then
  echo "All ${total} tests passed."
  exit 0
else
  echo "${failed}/${total} tests failed."
  exit 1
fi
