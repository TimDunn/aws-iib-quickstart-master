#!/bin/bash
# Script to run packer build and then aws cloud formation build
set -e
# Generate a unique identified for this build. UUID is the easiest
UUID=$(uuidgen)

# Pass the unique identifier to packer as a user variable
./local-build/packer-local.sh UUID=${UUID}
