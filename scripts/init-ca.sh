#!/bin/bash
# Initialize Neverlight CA
# Run as: sudo -u step bash /path/to/init-ca.sh

export STEPPATH=/home/step/.step

step-cli ca init \
  --name="Neverlight CA" \
  --dns="abyss.tailce879b.ts.net" \
  --dns="abyss" \
  --dns="localhost" \
  --dns="100.88.179.27" \
  --address=":8443" \
  --provisioner="admin@neverlight.local" \
  --acme
