#! /bin/bash
echo "Running deploy script...."
# Relies on HEX_API_KEY environment variable.
mix hex.publish --yes
