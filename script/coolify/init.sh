#!/bin/bash
set -euo pipefail

export RAILS_ENV=${RAILS_ENV:-production}

log() {
  printf '[coolify-init] %s\n' "$*"
}

if [[ -n "${CANVAS_DOMAIN:-}" ]]; then
  log "Ensuring config/domain.yml is set for ${CANVAS_DOMAIN}"
  cat > /usr/src/app/config/domain.yml <<EOF
production:
  domain: "${CANVAS_DOMAIN}"
  ssl: ${CANVAS_DOMAIN_SSL:-true}
EOF
  if [[ -n "${CANVAS_FILES_DOMAIN:-}" ]]; then
    printf '  files_domain: "%s"\n' "${CANVAS_FILES_DOMAIN}" >> /usr/src/app/config/domain.yml
  fi
fi

log "Ensuring config files exist..."
/usr/src/app/script/coolify/configure.sh

log "Creating database if needed..."
bundle exec rake db:create

log "Running migrations..."
bundle exec rake db:migrate

log "Checking if initial setup is required..."
if bundle exec rails runner 'exit(Account.default.present? ? 0 : 1)'; then
  log "Default account exists, skipping db:initial_setup"
else
  log "Running db:initial_setup (first-time setup)"
  bundle exec rake db:initial_setup
fi

if [[ -n "${CANVAS_PRODUCT_NAME:-}" ]]; then
  log "Setting product name to '${CANVAS_PRODUCT_NAME}'"
  bundle exec rails runner 'a=Account.default; if a; s=a.settings; s[:product_name]=ENV["CANVAS_PRODUCT_NAME"]; a.update!(settings: s); end'
fi

log "Init complete"
