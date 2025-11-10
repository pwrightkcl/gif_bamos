#!/bin/bash

# Edit this to set up your local registry as needed
registry="aicregistry"
port=5000
if [ -n "${registry}" ]; then
    prefix="${registry}"
    if [ -n "${port}" ]; then
        prefix="${prefix}:${port}/"

docker_tag=${prefix}${USER}:gif_bamos

docker build . -f Dockerfile \
 --network=host \
 --tag "${docker_tag}" \
 --build-arg USER_ID="$(id -u)" \
 --build-arg GROUP_ID="$(id -g)" \
 --build-arg USER="${USER}" \
# --no-cache

docker push "${docker_tag}"
