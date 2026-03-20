#!/bin/bash
set -euo pipefail

CONFIG_DIR=${CONFIG_DIR:-/usr/src/app/config}

log() {
  printf '[coolify-config] %s\n' "$*"
}

write_if_missing() {
  local name="$1"
  local target="$CONFIG_DIR/$name"
  local source="/usr/src/app/docker-compose/config/$name"
  if [[ -f "$target" ]]; then
    log "$name exists, skipping"
    return 0
  fi
  if [[ ! -f "$source" ]]; then
    log "missing source template $source"
    return 1
  fi
  log "creating $name from template"
  cp "$source" "$target"
}

write_if_missing database.yml
write_if_missing redis.yml
write_if_missing cache_store.yml
write_if_missing security.yml
write_if_missing delayed_jobs.yml
write_if_missing dynamic_settings.yml
write_if_missing outgoing_mail.yml
write_if_missing domain.yml

if [[ -n "${CANVAS_DOMAIN:-}" ]]; then
  log "writing domain.yml for ${CANVAS_DOMAIN}"
  cat > "$CONFIG_DIR/domain.yml" <<EOF2
production:
  domain: "${CANVAS_DOMAIN}"
  ssl: ${CANVAS_DOMAIN_SSL:-true}
EOF2
  if [[ -n "${CANVAS_FILES_DOMAIN:-}" ]]; then
    printf '  files_domain: "%s"\n' "${CANVAS_FILES_DOMAIN}" >> "$CONFIG_DIR/domain.yml"
  fi
fi

# Allow HTTP deployments by disabling force_ssl in production when requested.
if [[ "${CANVAS_DOMAIN_SSL:-true}" == "false" ]]; then
  local_env_dir="$CONFIG_DIR/environments"
  local_env_file="$local_env_dir/production-local.rb"
  if [[ ! -f "$local_env_file" ]]; then
    log "writing environments/production-local.rb to disable force_ssl"
    mkdir -p "$local_env_dir"
    cat > "$local_env_file" <<'EOF2'
CanvasRails::Application.configure do
  config.force_ssl = false
end
EOF2
  fi
fi
