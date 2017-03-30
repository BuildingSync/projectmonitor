# AUTHOR:           Nicholas Long
# DESCRIPTION:      BuildingSync Dashboard
# TO_BUILD_AND_RUN: docker-compose up
# NOTES:            This is the development docker-compose file.

FROM ubuntu:16.04
MAINTAINER Nicholas Long nicholas.long@nrel.gov

# Install required libaries
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	    autoconf \
	    build-essential \
		ca-certificates \
		cron \
		curl \
		default-jdk \
		git \
		gettext \
		qt-sdk \
		iputils-ping \
		tar \
		unzip \
		vim \
		wget \
		zip \
		# libraries
		libcurl4-openssl-dev \
		libmysqlclient-dev \
		libssl-dev \
		libv8-3.14.5 \
		libxml2-dev \
		zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

ENV RUBY_MAJOR=2.3 \
    RUBY_VERSION=2.3.1 \
    RUBY_DOWNLOAD_SHA256=b87c738cb2032bf4920fef8e3864dc5cf8eae9d89d8d523ce0236945c5797dcd \
    RUBYGEMS_VERSION=2.6.11 \
    BUNDLER_VERSION=1.14.6 \
    GEM_HOME=/usr/local/bundle \
    BUNDLE_SILENCE_ROOT_WARNING=1

# Interpretted env vars
ENV BUNDLE_PATH="$GEM_HOME" \
    BUNDLE_BIN="$GEM_HOME/bin" \
    BUNDLE_APP_CONFIG="$GEM_HOME" \
    PATH="$GEM_HOME/bin":$PATH

# Install Ruby, update rubygems, install bundler, skip installing gem documentation
# install Bundle context globally and don't create ".bundle" in all our apps
RUN mkdir -p /usr/local/etc \
    && { echo 'install: --no-document'; echo 'update: --no-document'; } >> /usr/local/etc/gemrc \
	&& curl -fSL -o ruby.tar.gz "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.gz" | sha256sum -c - \
	&& mkdir -p /usr/src/ruby \
	&& tar -xzf ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.gz \
	&& cd /usr/src/ruby \
	&& { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c \
	&& autoconf \
	&& ./configure --disable-install-doc --enable-shared \
	&& make -j"$(nproc)" \
	&& make install \
	&& rm -r /usr/src/ruby \
	&& cd ~ \
	&& gem update --system $RUBYGEMS_VERSION \
	&& gem install bundler --version "$BUNDLER_VERSION" \
	&& mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

# Install passenger (this also installs nginx)
ENV PASSENGER_VERSION 5.1.2
RUN gem install passenger -v $PASSENGER_VERSION \
    && passenger-install-nginx-module \
    && mkdir /var/log/nginx

# Set the rails env var and configure nginx
ARG rails_env=docker-development
ENV RAILS_ENV $rails_env
ADD /docker/server/nginx.template /opt/nginx/conf/nginx.template
RUN /bin/bash -c "envsubst < /opt/nginx/conf/nginx.template > /opt/nginx/conf/nginx.conf"


# Add source Gemfile and call bundle
RUN mkdir -p /opt/buildingsync/dashboard
ADD Gemfile /opt/buildingsync/dashboard/Gemfile
WORKDIR /opt/buildingsync/dashboard
RUN bundle install --jobs 20 --retry 5

# Add run-server script
RUN mkdir -p /etc/buildingsync
ADD /docker/server/run-server.sh /etc/buildingsync/run-server.sh
ADD /docker/server/run-workers.sh /etc/buildingsync/run-workers.sh

# wait-for-it script
ADD /docker/server/wait-for-it.sh /usr/local/wait-for-it.sh

# logs to stdout
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stdout /var/log/nginx/error.log

CMD ["/etc/buildingsync/run-server.sh"]
EXPOSE 8080
