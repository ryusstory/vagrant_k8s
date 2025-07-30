#!/bin/bash
echo "--- config.yaml sync start ---"
find /_shared/ -maxdepth 1 -type f -exec rm -f {} \;
if [[ ! -f /usr/local/bin/yq ]]; then
    sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq >/dev/null 2>&1 && sudo chmod +x /usr/local/bin/yq
fi
cp /usr/local/bin/yq /_shared/yq
ARGS_JSON=$1
echo "$ARGS_JSON" | yq -p=json -o yaml > /_shared/config.yaml
echo "--- config.yaml sync complete ---"