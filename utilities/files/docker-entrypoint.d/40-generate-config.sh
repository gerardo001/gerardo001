#!/bin/sh
set -eu

CONFIG_TEMPLATE="/usr/share/nginx/html/config.template.js"
CONFIG_FILE="/usr/share/nginx/html/config.js"

# Escape characters that break sed replacement.
escaped_sas_url=$(printf '%s' "${UPLOAD_SAS_URL:-}" | sed -e 's/[&/]/\\&/g')

sed "s/\${UPLOAD_SAS_URL}/$escaped_sas_url/g" "$CONFIG_TEMPLATE" > "$CONFIG_FILE"

if [ -z "${UPLOAD_SAS_URL:-}" ]; then
  echo "WARN: UPLOAD_SAS_URL is empty. The app will show a configuration error until set."
fi
