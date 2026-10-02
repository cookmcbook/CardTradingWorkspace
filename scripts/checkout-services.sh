#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

declare -A repositories=(
  [CardTradingPOC]="https://github.com/cookmcbook/CardTradingPOC.git"
  [CardTradingBackend]="https://github.com/cookmcbook/CardTradingBackend.git"
  [AuthenticationService]="https://github.com/cookmcbook/AuthenticationService.git"
)

for name in "${!repositories[@]}"; do
  path="$workspace_root/$name"
  if [[ -d "$path/.git" ]]; then
    echo "Updating $name"
    git -C "$path" pull --ff-only
  else
    echo "Cloning $name"
    git clone "${repositories[$name]}" "$path"
  fi
done
