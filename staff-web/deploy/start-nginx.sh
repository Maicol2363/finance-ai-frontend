#!/bin/sh
set -eu

export PORT="${PORT:-8080}"
if ! printf '%s\n' "$PORT" | awk 'NR != 1 || !/^[0-9]{1,5}$/ || $0 < 1024 || $0 > 65535 { exit 1 }'; then
    echo "PORT must be an unprivileged TCP port" >&2
    exit 1
fi

# Only accept a Cloud Run hostname. Keep the scheme, port and proxy path fixed.
if ! printf '%s\n' "${STAFF_API_HOST:-}" | awk '
    NR != 1 || !/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.run\.app$/ { exit 1 }
'; then
    echo "STAFF_API_HOST must be a Cloud Run hostname" >&2
    exit 1
fi

envsubst '$PORT $STAFF_API_HOST' < /etc/nginx/staff-web.conf.template > /tmp/staff-web.conf
exec nginx -c /tmp/staff-web.conf -g 'daemon off;'
