#!/usr/bin/env bash

# android-emulator-runner splits its `script` input at every newline and runs
# each resulting line in a separate shell. Keep this logic in one real script.
set -euo pipefail

api_base_url='http://10.0.2.2:8000'

flutter test --no-pub \
  integration_test/register_flow_test.dart \
  integration_test/release_financial_journeys_test.dart \
  --dart-define=RUN_REAL_AUTH_FLOW_TEST=true \
  --dart-define=RUN_REAL_FINANCIAL_JOURNEYS=true \
  --dart-define="FINANCE_AI_API_BASE_URL=${api_base_url}"
echo 'Android authentication and financial journeys passed.'
