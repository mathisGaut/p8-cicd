#!/usr/bin/env bash
#
# Unified test runner for OpenClassrooms P8 (Angular + Spring Boot / Gradle).
# Generates JUnit XML reports under test-results/ for use in CI (e.g. GitHub Actions).
#

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${ROOT}/test-results"
ANGULAR_RESULTS="${RESULTS_DIR}/angular"
JAVA_RESULTS="${RESULTS_DIR}/java"

angular_dir=""
java_dir=""
angular_status=0
java_status=0

log() {
  printf '[run-tests] %s\n' "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_command() {
  local cmd=$1
  local hint=${2:-}
  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [[ -n "$hint" ]]; then
      fail "Required command '$cmd' not found. $hint"
    fi
    fail "Required command '$cmd' not found."
  fi
}

find_angular_project() {
  local dir
  for dir in "$ROOT"/*/; do
    [[ -d "$dir" ]] || continue
    [[ -L "${dir%/}" ]] && continue
    [[ -f "${dir}package.json" ]] || continue
    if grep -q '"@angular/core"' "${dir}package.json" 2>/dev/null; then
      printf '%s' "${dir%/}"
      return 0
    fi
  done
  return 1
}

find_java_project() {
  local dir
  for dir in "$ROOT"/*/; do
    [[ -d "$dir" ]] || continue
    [[ -L "${dir%/}" ]] && continue
    [[ -f "${dir}gradlew" ]] && [[ -f "${dir}build.gradle" ]] || continue
    printf '%s' "${dir%/}"
    return 0
  done
  return 1
}

check_prerequisites() {
  require_command node "Install Node.js 20+ (see Angular README)."
  require_command npm "Install npm (bundled with Node.js)."
  require_command java "Install JDK 21 (see Java README)."

  angular_dir="$(find_angular_project)" || fail "No Angular project found (expected package.json with @angular/core)."
  java_dir="$(find_java_project)" || fail "No Gradle/Java project found (expected gradlew and build.gradle)."

  log "Angular project: ${angular_dir}"
  log "Java project:    ${java_dir}"

  if [[ "${angular_dir}" == *"'"* ]]; then
    log "WARNING: Angular project path contains an apostrophe (')."
    log "          Angular/esbuild test builds may fail; prefer an ASCII clone path (e.g. GitHub folder name)."
  fi

  if [[ ! -d "${angular_dir}/node_modules" ]]; then
    fail "Angular dependencies missing. Run: (cd \"${angular_dir}\" && npm ci)"
  fi

  if [[ ! -x "${java_dir}/gradlew" ]]; then
    chmod +x "${java_dir}/gradlew" || fail "Cannot execute gradlew in ${java_dir}"
  fi
}

clean_results_dir() {
  log "Cleaning ${RESULTS_DIR}"
  rm -rf "${RESULTS_DIR}"
  mkdir -p "${ANGULAR_RESULTS}" "${JAVA_RESULTS}"
}

copy_junit_reports() {
  local source_dir=$1
  local pattern=$2
  local dest_dir=$3
  local label=$4

  shopt -s nullglob
  local files=( "${source_dir}"/${pattern} )
  shopt -u nullglob

  if (( ${#files[@]} == 0 )); then
    log "WARNING: No JUnit XML reports found for ${label} (looked in ${source_dir}/${pattern})"
    return 1
  fi

  cp -f "${files[@]}" "${dest_dir}/"
  log "${label}: copied ${#files[@]} JUnit report(s) to ${dest_dir}"
  return 0
}

run_angular_tests() {
  log "Running Angular tests (npm test)..."
  set +e
  (
    cd "${angular_dir}" || exit 1
    npm test
  )
  angular_status=$?
  set -e

  if (( angular_status != 0 )); then
    log "Angular tests failed (exit ${angular_status})"
  else
    log "Angular tests passed"
  fi

  copy_junit_reports "${angular_dir}/reports" "*.xml" "${ANGULAR_RESULTS}" "Angular" || true
}

run_java_tests() {
  log "Running Java tests (./gradlew clean test)..."
  set +e
  (
    cd "${java_dir}" || exit 1
    ./gradlew clean test --no-daemon
  )
  java_status=$?
  set -e

  if (( java_status != 0 )); then
    log "Java tests failed (exit ${java_status})"
  else
    log "Java tests passed"
  fi

  copy_junit_reports "${java_dir}/build/test-results/test" "TEST-*.xml" "${JAVA_RESULTS}" "Java" || true
}

main() {
  check_prerequisites
  clean_results_dir
  run_angular_tests
  run_java_tests

  if (( angular_status != 0 || java_status != 0 )); then
    log "One or more test suites failed."
    exit 1
  fi

  log "All tests passed."
  exit 0
}

main "$@"
