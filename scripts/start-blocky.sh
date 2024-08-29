#!/usr/bin/env bash
set -E -e -o pipefail

blocky_config="/data/blocky/config/config.yml"

set_umask() {
    # Configure umask to allow write permissions for the group by default
    # in addition to the owner.
    umask 0002
}

setup_blocky_config() {
    echo "Checking for existing Blocky config ..."
    echo

    if [ -f "${blocky_config:?}" ]; then
        echo "Existing Blocky configuration \"${blocky_config:?}\" found"
    else
        echo "Generating Blocky configuration at ${blocky_config:?}"
        cat << EOF > ${blocky_config:?}
ports:
  dns: 53
  http: 4000

upstreams:
  init:
    strategy: failOnError
  groups:
    default:
      - 1.1.1.1
      - 1.0.0.1

bootstrapDns:
  - tcp+udp:1.1.1.1
  - tcp+udp:1.0.0.1

blocking:
  denylists:
    ads:
      - https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
      - https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
      - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
      - http://sysctl.org/cameleon/hosts
    fakenews:
      - https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts
  clientGroupsBlock:
    default:
      - ads
      - fakenews
  loading:
    strategy: failOnError
EOF
    fi

    echo
    echo
}

start_blocky() {
    echo "Starting Blocky ..."
    echo

    local blocky_host="${BLOCKY_HOST:-blockyhost}"
    unset BLOCKY_HOST

    exec blocky serve --apiHost "${blocky_host:?}" --apiPort 4000 --config "${blocky_config:?}"
}

set_umask
setup_blocky_config
start_blocky
