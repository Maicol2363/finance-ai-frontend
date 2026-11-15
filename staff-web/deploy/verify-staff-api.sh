#!/usr/bin/env bash
set -euo pipefail

api_url="$1"
staff_origin="$2"
[[ "$api_url" =~ ^https://[a-z0-9.-]+\.run\.app$ ]]
[[ "$staff_origin" =~ ^https://[a-z0-9.-]+\.run\.app$ ]]
response=$(mktemp)
trap 'rm -f "$response"' EXIT

expect_status() {
    local expected_status="$1"
    local expected_code="$2"
    local path="$3"
    shift 3
    local status
    status=$(curl --silent --show-error --max-time 25 \
        --output "$response" --write-out '%{http_code}' "$@" "${api_url}/api/v1/staff/${path}")
    if [[ "$status" != "$expected_status" ]] ||
        ! jq -e --arg code "$expected_code" '.code == $code' "$response" >/dev/null; then
        printf 'Staff API check failed for %s (expected HTTP %s/%s, got HTTP %s).\n' \
            "$path" "$expected_status" "$expected_code" "$status" >&2
        exit 1
    fi
    printf 'Staff API %s returned HTTP %s/%s.\n' "$path" "$status" "$expected_code"
}

for path in auth/session support/tickets audit/events; do
    expect_status 401 authentication_required "$path" \
        -H 'X-Staff-Request: 1' -H 'Sec-Fetch-Site: same-origin'
done

expect_status 403 staff_request_denied auth/session -H 'Sec-Fetch-Site: same-origin'
expect_status 403 staff_origin_denied auth/session -H 'X-Staff-Request: 1' \
    -H 'Origin: https://foreign-origin.invalid'
# Without cookies this reaches authentication after origin and HTTPS checks.
expect_status 401 session_invalid auth/refresh -H 'X-Staff-Request: 1' \
    -H "Origin: $staff_origin" -H 'Content-Type: application/json' --data '{}'
