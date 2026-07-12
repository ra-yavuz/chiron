#!/bin/bash
set -euo pipefail

src="${1:?usage: backup.sh <dir>}"
dest="backup-$(date +%Y%m%d).tar.gz"

tar -czf "$dest" "$src"
echo "wrote $dest"
