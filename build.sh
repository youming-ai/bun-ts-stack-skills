#!/usr/bin/env bash
#!/usr/bin/env bash
# Build the TanStack skill package.

set -euo pipefail

mkdir -p dist
rm -f dist/tanstack.skill
zip -qr dist/tanstack.skill tanstack -x '*.DS_Store'
echo '✓ dist/tanstack.skill'
