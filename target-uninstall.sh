#! /usr/bin/env bash
# Remove a single YHTTP deployment.  Database and uploaded media are retained.

set -u

HERE="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
SCRIPT_NAME="$(basename "$0")"

if [ "${EUID}" -ne 0 ]; then
  echo "This uninstaller must be run as root." >&2
  exit 1
fi

# The installed command derives its
# durable state file from <instance>-uninstall.sh.
if [[ "${SCRIPT_NAME}" =~ ^([A-Za-z0-9][A-Za-z0-9_.-]*)-uninstall\.sh$ ]]; then
  statefile="/etc/yhttp-deploy/${BASH_REMATCH[1]}.vars"
else
  echo "Cannot determine deployment state for ${SCRIPT_NAME}." >&2
  exit 1
fi

if [ ! -r "${statefile}" ]; then
  echo "Deployment state file ${statefile} does not exist." >&2
  exit 1
fi

# State files are written by target-install.sh from the bundle's existing .vars
# format.  Validate every value before using it in paths or service commands.
source "${statefile}"

valid_name() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] && [ "$1" != "." ] && [ "$1" != ".." ]
}

for value in "${user:-}" "${instance:-}" "${pypkg:-}" "${nginxconfigfile:-}"; do
  if ! valid_name "${value}"; then
    echo "Invalid deployment state in ${statefile}." >&2
    exit 1
  fi
done

if [[ "${userconfigfile:-}" == */* || "${userconfigfile:-}" == "." || "${userconfigfile:-}" == ".." || -z "${userconfigfile:-}" ]]; then
  echo "Invalid user configuration name in ${statefile}." >&2
  exit 1
fi

if [[ "${SCRIPT_NAME}" != "uninstall.sh" && "${SCRIPT_NAME}" != "${instance}-uninstall.sh" ]]; then
  echo "State file instance does not match this uninstall command." >&2
  exit 1
fi

pyenv="/home/${user}/.pyenv"
configdir="/home/${user}/.config"
vardir="/home/${user}/.var"
systemd_unit="${configdir}/systemd/user/${instance}.service"
nginx_available="/etc/nginx/sites-available/${nginxconfigfile}"
nginx_enabled="/etc/nginx/sites-enabled/${nginxconfigfile}"
uninstall_command="/usr/local/bin/${instance}-uninstall.sh"
confirm_all=false

note() {
  echo "[uninstall] $*"
}

warn() {
  echo "[uninstall] warning: $*" >&2
}

remove_file() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    if confirm_remove "file" "$1"; then
      rm -f -- "$1"
      note "removed $1"
      return 0
    fi
    note "retained $1"
    return 1
  fi
  return 1
}

remove_tree() {
  if [ -d "$1" ]; then
    if confirm_remove "directory and its contents" "$1"; then
      rm -rf -- "$1"
      note "removed $1"
      return 0
    fi
    note "retained $1"
    return 1
  fi
  return 1
}

confirm_remove() {
  local kind="$1"
  local path="$2"
  local answer

  if [ ! -t 0 ]; then
    warn "not removing ${path}: an interactive terminal is required"
    return 1
  fi

  if ${confirm_all}; then
    return 0
  fi

  read -r -p "Remove ${kind} ${path}? [y/N/a] " answer
  case "${answer}" in
    [Yy]|[Yy][Ee][Ss])
      return 0
      ;;
    [Aa]|[Aa][Ll][Ll])
      confirm_all=true
      note "all remaining removals confirmed"
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Stop first so the socket is no longer recreated while deployment files are
# removed.  A failed or absent unit is normal during recovery.
if systemctl is-enabled "${instance}.service" >/dev/null 2>&1; then
  if confirm_remove "systemd enablement links for service" "${instance}.service"; then
    systemctl disable "${instance}.service" || warn "could not disable ${instance}.service"
  else
    note "retained enablement for ${instance}.service"
  fi
fi
if systemctl is-active "${instance}.service" >/dev/null 2>&1; then
  note "stopping ${instance}.service"
  systemctl stop "${instance}.service" || warn "could not stop ${instance}.service"
fi
remove_file "${systemd_unit}"
systemctl daemon-reload || warn "could not reload systemd"

# Only delete nginx configuration if this installer demonstrably owns it.  New
# installs carry a marker; older installs are recognized by their unique socket.
nginx_owned=false
if [ -f "${nginx_available}" ]; then
  if grep -Fqx "# Managed by yhttp-deploy: instance=${instance}" "${nginx_available}" \
    || grep -Fq "uwsgi_pass unix:${vardir}/${instance}.s;" "${nginx_available}"; then
    nginx_owned=true
  else
    warn "retaining ambiguous nginx config ${nginx_available}"
  fi
fi

if ${nginx_owned}; then
  nginx_backup="$(mktemp "/tmp/${instance}-nginx.XXXXXX")"
  cp -p -- "${nginx_available}" "${nginx_backup}"
  enabled_target=""
  if [ -L "${nginx_enabled}" ]; then
    enabled_target="$(readlink "${nginx_enabled}")"
  fi
  nginx_changed=false
  if remove_file "${nginx_enabled}"; then
    nginx_changed=true
  fi
  if remove_file "${nginx_available}"; then
    nginx_changed=true
  fi
  if ${nginx_changed} && nginx -t >/dev/null 2>&1; then
    systemctl reload nginx || warn "could not reload nginx"
  elif ${nginx_changed}; then
    warn "nginx configuration test failed; restoring ${nginx_available}"
    cp -p -- "${nginx_backup}" "${nginx_available}"
    if [ -n "${enabled_target}" ]; then
      ln -s -- "${enabled_target}" "${nginx_enabled}"
    fi
  fi
  remove_file "${nginx_backup}"
fi

# Check for another unit sharing this user's runtime before removing files that
# are not instance-namespaced.  Missing/unreadable units are conservatively
# ignored rather than causing the uninstall to fail.
pyenv_shared=false
web_runtime_shared=false
while IFS= read -r unit; do
  if [ "${unit}" = "${systemd_unit}" ]; then
    continue
  fi
  if grep -Fq "${pyenv}" "${unit}"; then
    pyenv_shared=true
    warn "retaining ${pyenv}; it is referenced by ${unit}"
  fi
  if grep -Fq "${vardir}" "${unit}"; then
    web_runtime_shared=true
    warn "retaining shared web runtime; it is referenced by ${unit}"
  fi
done < <(find /etc/systemd/system /home -type f -name '*.service' 2>/dev/null)

# Remove only generated runtime/configuration.  Media and PostgreSQL are
# deliberately preserved for recovery or a later reinstallation.
remove_file "${configdir}/${pypkg}.yml"
remove_file "${configdir}/${pypkg}-${userconfigfile}"
remove_file "${configdir}/${instance}_wsgi.py"
remove_file "${configdir}/${instance}_uwsgi.ini"
remove_file "${vardir}/${instance}.s"

if ! ${web_runtime_shared}; then
  remove_file "${configdir}/assets-manifest.json"
  remove_tree "${vardir}/mako"
  remove_tree "${vardir}/www/assets"
  remove_tree "${vardir}/www/public"
fi

if ! ${pyenv_shared}; then
  remove_tree "${pyenv}"
fi

remove_file "${uninstall_command}"
remove_file "/etc/yhttp-deploy/${instance}.vars"
note "uninstall complete; database and ${vardir}/www/media were retained"
