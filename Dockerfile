ARG RUBY_ENV=ruby:3.0

FROM $RUBY_ENV as base

RUN mkdir -p /app
WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install
