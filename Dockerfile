FROM odoo:14
MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
#ENV LANG C.UTF-8
USER root
# explicitly set user/group IDs


RUN set -ex; \
# pub   4096R/ACCC4CF8 2011-10-13 [expires: 2019-07-02]
#       Key fingerprint = B97B 0AFC AA1A 47F0 44F2  44A0 7FCC 7D46 ACCC 4CF8
# uid                  PostgreSQL Debian Repository
	key='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8'; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	gpg --batch --export "$key" > /etc/apt/trusted.gpg.d/postgres.gpg; \
	command -v gpgconf > /dev/null && gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	apt-key list

ENV PG_MAJOR 13
ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin

ENV PG_VERSION 13.4-1.pgdg100+1


# install latest postgresql-client

RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install -y --no-install-recommends postgresql-common \
    && apt-get install -y --no-install-recommends postgresql-13=13.4-1.pgdg100+1 \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

#RUN set -eux; \
#	groupadd -r odoo --gid=999; \
# https://salsa.debian.org/postgresql/postgresql-common/blob/997d842ee744687d99a2b2d95c1083a2615c79e8/debian/postgresql-common.postinst#L32-35
#	useradd -r -g odoo --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash odoo; \
# also create the postgres user's home directory with appropriate permissions
# see https://github.com/docker-library/postgres/issues/274
#	mkdir -p /var/lib/postgresql; \
#	chown -R odoo:odoo /var/lib/postgresql; \
#    chown -R odoo:odoo /var/log/postgresql; \
#    chown -R odoo:odoo /etc/ssl/private/ssl-cert-snakeoil.key;\
#    chown -R odoo:odoo /etc/ssl/private

# Install rtlcss (on Debian buster)

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN chown odoo /etc/odoo/odoo.conf \
    && mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons \
    && chmod -R 777 /entrypoint.sh \
    && chmod -R 777 /usr/local/bin/wait-for-psql.py 
    
ENV PGDATA /var/lib/postgresql/data

USER postgres
RUN /etc/init.d/postgresql start  && psql --command "CREATE USER root WITH SUPERUSER CREATEDB REPLICATION;create role odoo superuser login;alter user odoo password 'odoo'; "
USER root

RUN mkdir -p "$PGDATA" && chown -R odoo:odoo "$PGDATA" && chmod 777 "$PGDATA" \
    && chmod -R 777 /var/run/postgresql

VOLUME ["/var/lib/odoo", "/mnt/extra-addons" , "/var/lib/postgresql/data"]

# Expose Odoo services
EXPOSE 8069 8071 8072 5432

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf



# Set default user when running the container
#USER odoo
#USER root

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
