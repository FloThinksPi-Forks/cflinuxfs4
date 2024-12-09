ARG base
FROM $base
ARG locales
ARG packages
ARG package_args='--allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends'
ARG user_id=2000
ARG group_id=2000

COPY packages/sources.list /etc/apt/sources.list

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

RUN sed -i s/#PermitRootLogin.*/PermitRootLogin\ no/ /etc/ssh/sshd_config && \
  sed -i s/#PasswordAuthentication.*/PasswordAuthentication\ no/ /etc/ssh/sshd_config

RUN echo 'LANG="en_US.UTF-8"' > /etc/default/locale && \
  echo "$locales" | grep -f - /usr/share/i18n/SUPPORTED | cut -d " " -f 1 | xargs locale-gen && \
  dpkg-reconfigure -fnoninteractive -pcritical locales tzdata libc6

RUN useradd -u ${user_id} -mU -s /bin/bash vcap && \
  mkdir /home/vcap/app && \
  chown vcap:vcap /home/vcap/app && \
  ln -s /home/vcap/app /app

RUN printf '\n%s\n' >> "/etc/ssl/openssl.cnf" \
  '# Allow user-set openssl.cnf' \
  '.include /tmp/app/openssl.cnf' \
  '.include /home/vcap/app/openssl.cnf'

USER ${user_id}:${group_id}
