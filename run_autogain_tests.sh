#!/usr/bin/env bash

# Build readsb_autogain_testing_base image image
# (just mikenye/readsb-protobuf, tagged differently for the following build)
docker build -t readsb_autogain_testing_base .

# Build readsb_autogain_testing image
# (just mikenye/readsb-protobuf including spoofed stats.pb files used by testing)
docker build -f Dockerfile.autogain_testing -t readsb_autogain_testing .

# Run autogain tests
docker run --rm -it readsb_autogain_testing
