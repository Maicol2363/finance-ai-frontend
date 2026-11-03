#!/usr/bin/env bash

# android-emulator-runner splits its `script` input at every newline and runs
# each resulting line in a separate shell. Keep this logic in one real script
# so multiline commands and their exit statuses work as intended.
set -u

api_base_url='http://10.0.2.2:8000'
auth_status=0
financial_status=0

if flutter test integration_test/register_flow_test.dart \
  --dart-define=RUN_REAL_AUTH_FLOW_TEST=true \
  --dart-define="FINANCE_AI_API_BASE_URL=${api_base_url}"; then
  echo 'Authentication journey passed.'
else
  auth_status=$?
  echo "Authentication journey failed with exit code ${auth_status}." >&2
fi

if flutter test integration_test/release_financial_journeys_test.dart \
  --dart-define=RUN_REAL_FINANCIAL_JOURNEYS=true \
  --dart-define="FINANCE_AI_API_BASE_URL=${api_base_url}"; then
  echo 'Financial journeys passed.'
else
  financial_status=$?
  echo "Financial journeys failed with exit code ${financial_status}." >&2
fi

if [[ "${auth_status}" -ne 0 || "${financial_status}" -ne 0 ]]; then
  exit 1
fi
