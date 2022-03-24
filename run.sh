#!/usr/bin/env bash

docker build . -t get-gitlab-issues
docker run --rm -it -v $(pwd):/app get-gitlab-issues bundle exec ruby bin/exec.rb
