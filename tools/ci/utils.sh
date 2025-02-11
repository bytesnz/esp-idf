# Modified from https://gitlab.com/gitlab-org/gitlab/-/blob/master/scripts/utils.sh

function add_ssh_keys() {
  local key_string="${1}"
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  echo -n "${key_string}" >~/.ssh/id_rsa_base64
  base64 --decode --ignore-garbage ~/.ssh/id_rsa_base64 >~/.ssh/id_rsa
  chmod 600 ~/.ssh/id_rsa
}

function add_gitlab_ssh_keys() {
  add_ssh_keys "${GITLAB_KEY}"
  echo -e "Host gitlab.espressif.cn\n\tStrictHostKeyChecking no\n" >>~/.ssh/config

  # For gitlab geo nodes
  if [ "${LOCAL_GITLAB_SSH_SERVER:-}" ]; then
    SRV=${LOCAL_GITLAB_SSH_SERVER##*@} # remove the chars before @, which is the account
    SRV=${SRV%%:*}                     # remove the chars after :, which is the port
    printf "Host %s\n\tStrictHostKeyChecking no\n" "${SRV}" >>~/.ssh/config
  fi
}

function add_github_ssh_keys() {
  add_ssh_keys "${GH_PUSH_KEY}"
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >>~/.ssh/config
}

function add_doc_server_ssh_keys() {
  local key_string="${1}"
  local server_url="${2}"
  local server_user="${3}"
  add_ssh_keys "${key_string}"
  echo -e "Host ${server_url}\n\tStrictHostKeyChecking no\n\tUser ${server_user}\n" >>~/.ssh/config
}

function fetch_submodules() {
  python "${SUBMODULE_FETCH_TOOL}" -s "${SUBMODULES_TO_FETCH}"
}

function get_all_submodules() {
  git config --file .gitmodules --get-regexp path | awk '{ print $2 }' | sed -e 's|$|/**|' | xargs | sed -e 's/ /,/g'
}

function error() {
  printf "\033[0;31m%s\n\033[0m" "${1}" >&2
}

function info() {
  printf "\033[0;32m%s\n\033[0m" "${1}" >&2
}

function warning() {
  printf "\033[0;33m%s\n\033[0m" "${1}" >&2
}

function run_cmd() {
  local start=$(date +%s)
  eval "$@"
  local ret=$?
  local end=$(date +%s)
  local duration=$((end - start))

  if [[ $ret -eq 0 ]]; then
    info "(\$ $*) succeeded in ${duration} seconds."
    return 0
  else
    error "(\$ $*) failed in ${duration} seconds."
    return $ret
  fi
}

# Retries a command RETRY_ATTEMPTS times in case of failure
# Inspired by https://stackoverflow.com/a/8351489
function retry_failed() {
  local max_attempts=${RETRY_ATTEMPTS-3}
  local timeout=${RETRY_TIMEWAIT-1}
  local attempt=1
  local exitCode=0

  whole_start=$(date +%s)
  while true; do
    if run_cmd "$@"; then
      exitCode=0
      break
    else
      exitCode=$?
    fi

    if ((attempt >= max_attempts)); then
      break
    fi

    error "Retrying in ${timeout} seconds..."
    sleep $timeout
    attempt=$((attempt + 1))
    timeout=$((timeout * 2))
  done

  local duration=$(($(date '+%s') - whole_start))
  if [[ $exitCode != 0 ]]; then
    error "Totally failed! Spent $duration sec in total"
  else
    info "Done! Spent $duration sec in total"
  fi
  return $exitCode
}

function internal_pip_install() {
    project=$1
    package=$2
    token_name=${3:-${BOT_TOKEN_NAME}}
    token=${4:-${BOT_TOKEN}}
    python=${5:-python}

    $python -m pip install --index-url https://${token_name}:${token}@${GITLAB_HTTPS_HOST}/api/v4/projects/${project}/packages/pypi/simple --force-reinstall --no-deps ${package}
}
