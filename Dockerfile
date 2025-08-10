FROM ruby:latest
ENV DEBIAN_FRONTEND noninteractive

Label MAINTAINER Amir Pourmand

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    locales \
    imagemagick \
    build-essential \
    zlib1g-dev \
    jupyter-nbconvert \
    inotify-tools procps && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*


RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen


ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    JEKYLL_ENV=production \
    SASS_SILENCE_DEPRECATIONS=* \
    SCSS_SILENCE_DEPRECATIONS=*

RUN mkdir /srv/jekyll

ADD Gemfile /srv/jekyll

WORKDIR /srv/jekyll

RUN gem install jekyll bundler

RUN bundle install

COPY bin/entry_point.sh /tmp/entry_point.sh
RUN sed -i 's/\r$//' /tmp/entry_point.sh && chmod +x /tmp/entry_point.sh
EXPOSE 8080


CMD ["/tmp/entry_point.sh"]
