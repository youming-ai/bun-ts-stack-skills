#!/usr/bin/env bash
# Build .skill packages from each skill directory.
# Output goes to ./dist/

set -euo pipefail

SKILLS=(tanstack astro)
DIST="dist"

mkdir -p "$DIST"

for skill in "${SKILLS[@]}"; do
  if [ ! -f "$skill/SKILL.md" ]; then
    echo "✗ $skill/SKILL.md not found, skipping"
    continue
  fi

  out="$DIST/${skill}.skill"
  rm -f "$out"

  # .skill is a zip with the skill folder at the root
  zip -qr "$out" "$skill" -x "*.DS_Store"
  echo "✓ $out"
done

echo
echo "Done. Upload the .skill files in Claude's skill settings."
