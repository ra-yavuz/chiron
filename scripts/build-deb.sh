#!/bin/bash
# Build a .deb without debhelper: produces an equivalent binary package
# layout under dist/ using only dpkg-deb. Mirrors the ra-yavuz house
# pattern (see inhibit-charge).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"

VERSION="$(sed -nE '1 s/^[^(]*\(([^)-]+)[^)]*\).*/\1/p' debian/changelog)"
[ -n "$VERSION" ] || { echo "build-deb.sh: cannot parse version from debian/changelog" >&2; exit 1; }

pkg="chiron_${VERSION}_all"
stage="dist/$pkg"
rm -rf "$stage"
mkdir -p "$stage/DEBIAN" \
         "$stage/usr/bin" \
         "$stage/usr/share/chiron/kit/doctrine" \
         "$stage/usr/share/chiron/kit/adapters/claude-code/hooks" \
         "$stage/usr/share/chiron/kit/adapters/codex" \
         "$stage/usr/share/doc/chiron"

install -m 0755 bin/chiron "$stage/usr/bin/chiron"
install -m 0644 doctrine/doctrine.md doctrine/reminder.md \
    "$stage/usr/share/chiron/kit/doctrine/"
install -m 0755 adapters/claude-code/hooks/*.sh \
    "$stage/usr/share/chiron/kit/adapters/claude-code/hooks/"
install -m 0644 adapters/claude-code/settings-fragment.json \
    "$stage/usr/share/chiron/kit/adapters/claude-code/"
install -m 0644 adapters/codex/AGENTS.md \
    "$stage/usr/share/chiron/kit/adapters/codex/"
install -m 0644 README.md TOOLING.md "$stage/usr/share/doc/chiron/"
install -m 0644 LICENSE "$stage/usr/share/doc/chiron/copyright"

cat > "$stage/DEBIAN/control" <<CONTROL_EOF
Package: chiron
Version: ${VERSION}-1
Section: utils
Priority: optional
Architecture: all
Depends: bash, python3
Recommends: git
Maintainer: Ramazan Yavuz <yavuzramazan1994@gmail.com>
Homepage: https://ra-yavuz.github.io/chiron/
Description: mentor kit for coding agents: doctrine plus enforcement hooks
 Installs an operating doctrine and mechanical enforcement hooks into
 coding-agent harnesses (Claude Code, Codex CLI) so weaker models work
 with the discipline of stronger ones: verify before acting, no
 workarounds, no deleted tests, no unverified completion claims.
 Includes an install/doctor CLI. The A/B eval harness that measures the
 kit's effect lives in the source repository.
 .
 DISCLAIMER: This software modifies agent-harness configuration files
 and injects instructions into model sessions. It is provided AS IS,
 WITHOUT WARRANTY OF ANY KIND. You alone are responsible for reviewing
 what it installs and for anything a configured agent does. The author
 is not liable for any damage arising from its use. If you do not
 accept these terms, do not install this package.
CONTROL_EOF

dpkg-deb --build --root-owner-group "$stage" "dist/$pkg.deb"
echo "build-deb.sh: built dist/$pkg.deb"
