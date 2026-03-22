#!/bin/sh
set -eu

pattern='static let cardSpacing: CGFloat = 16'

if rg -q "$pattern" "Bangumi/Shared/Design/BangumiDesign.swift"; then
  exit 0
fi

echo "Expected discovery hero card spacing to be 16pt." >&2
exit 1
