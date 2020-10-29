#!/usr/bin/env sh
#shellcheck shell=sh

REPO=mikenye
IMAGE=readsb-protobuf
PLATFORMS="linux/386,linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64"
LATEST_TAG=beta

docker context use x86_64
export DOCKER_CLI_EXPERIMENTAL="enabled"
docker buildx use homecluster

# Build & push latest
docker buildx build --no-cache -t "${REPO}/${IMAGE}:${LATEST_TAG}" --compress --push --platform "${PLATFORMS}" .

# Get readsb version from latest
docker pull "${REPO}/${IMAGE}:${LATEST_TAG}"
VERSION=$(docker run --rm --entrypoint readsb "${REPO}/${IMAGE}:${LATEST_TAG}" --version | cut -d " " -f 2)

# Build & push version-specific
docker buildx build -t "${REPO}/${IMAGE}:${VERSION}" --compress --push --platform "${PLATFORMS}" .

# BUILD NOHEALTHCHECK VERSION
# Modify dockerfile to remove healthcheck
sed '/^HEALTHCHECK /d' < Dockerfile > Dockerfile.nohealthcheck

# Build & push latest
docker buildx build -f Dockerfile.nohealthcheck -t "${REPO}/${IMAGE}:${LATEST_TAG}_nohealthcheck" --compress --push --platform "${PLATFORMS}" .

# If there are version differences, build & push with a tag matching the build date
docker buildx build -f Dockerfile.nohealthcheck -t "${REPO}/${IMAGE}:${VERSION}_nohealthcheck" --compress --push --platform "${PLATFORMS}" .
