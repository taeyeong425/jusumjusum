#!/bin/bash
# 사용: .tools/godot.sh <초> [godot 인자...]   — 시간 제한 걸고 Godot 실행
T=$1; shift
DIR="$(cd "$(dirname "$0")" && pwd)"
exec perl -e 'alarm shift; exec @ARGV' "$T" "$DIR/Godot.app/Contents/MacOS/Godot" "$@"
