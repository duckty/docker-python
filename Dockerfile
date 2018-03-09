FROM python:2.7
MAINTAINER Inspectorio DevOps <devops@inspectorio.com>

ARG DEBIAN_FRONTEND=noninteractive

ENV APP_USER  app
ENV APP_GRP   app
ENV APP_HOME  /app
ENV APP_SHELL /bin/bash
ENV NGINX_WORKER 4
ENV PIP_NO_CACHE_DIR 1
ENV PIP_CACHE_DIR /tmp/

ONBUILD ADD . "${APP_HOME}"
ONBUILD ADD config /etc
ONBUILD WORKDIR "${APP_HOME}"
ONBUILD RUN pipenv install --system --deploy && chown -R "${APP_USER}":"${APP_GRP}" "${APP_HOME}"
ONBUILD USER "${APP_USER}"

COPY requirements.txt /tmp/requirements.txt
COPY entrypoint.sh /tmp/entrypoint.sh
COPY config /etc/

RUN groupadd -r "${APP_GRP}" \
&&  groupadd -r supervisor \
&&  useradd --create-home --home-dir "${APP_HOME}" --shell "${APP_SHELL}" --gid "${APP_GRP}" "${APP_USER}" \
&&  usermod -a -G supervisor "${APP_USER}" \
&&  mv /tmp/entrypoint.sh ${APP_HOME}/entrypoint.sh \
&&  chown -R "${APP_USER}":"${APP_GRP}" "${APP_HOME}" \
&&  apt-get -qq -y update \
&&  apt-get install -qq -o Dpkg::Options::="--force-confold" \
                    -y --no-install-recommends \
                    sudo supervisor gettext-base locales tzdata lsb-release \
                    jq curl vim-nox openssh-client \
&&  /bin/bash -c "envsubst < /etc/sudoers.d/99-app > /etc/sudoers.d/99-app" \
&&  /bin/bash -c "envsubst < /etc/supervisor/supervisord.conf > /etc/supervisor/supervisord.conf" \
&&  chmod 0755 /etc/sudoers.d && chmod 0640 /etc/sudoers.d/99-app \
&&  curl -sSL http://nginx.org/keys/nginx_signing.key | apt-key add - \
&&  echo "deb http://nginx.org/packages/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/ $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list \
&&  apt-get -qq -y update \
&&  apt-get -qq -o Dpkg::Options::="--force-confold" -y install nginx \
&&  /bin/rm -f /etc/nginx/nginx.conf.dpkg-dist /etc/supervisor/supervisord.conf.dpkg-dist \
&&  ln -sf /dev/stdout /var/log/nginx/access.log \
&&  ln -sf /dev/stderr /var/log/nginx/error.log \
&&  rm -f /etc/nginx/conf.d/* /etc/nginx/sites-enabled/* \
&&  pip install --no-cache-dir -U -r /tmp/requirements.txt \
&&  apt-get clean \
&&  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER app
WORKDIR /app

EXPOSE 5000
CMD ["/app/entrypoint.sh"]