ARG base
FROM ${base}

ARG packages
ARG package_args='--allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends'

RUN --mount=type=secret,id=pro-attach-config <<-EODI
  set -eu
  echo "debconf debconf/frontend select noninteractive" | debconf-set-selections
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y $package_args update
  if [ -s /run/secrets/pro-attach-config ]; then
	apt-get -y $package_args install ubuntu-pro-client ca-certificates
	pro attach --attach-config /run/secrets/pro-attach-config
  fi
  apt-get -y $package_args update
  apt-get -y $package_args dist-upgrade
  apt-get -y $package_args install $packages
  if [ -s /run/secrets/pro-attach-config ]; then
	pro detach --assume-yes
	apt-get purge --auto-remove -y ubuntu-pro-client
  fi
  apt-get clean
  rm -rf /var/lib/apt/lists/*
  find /usr/share/doc/*/* ! -name copyright | xargs rm -rf
EODI
