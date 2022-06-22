#!/bin/bash

set -ex

RELEASE_DIR=_build/prod/rel/homelander
WORK_DIR=tmp-makeself
MAIN_SCRIPT_RELATIVE=bin/homelander_start.sh
MAIN_SCRIPT="$WORK_DIR/rel/$MAIN_SCRIPT_RELATIVE"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup SIGINT SIGTERM EXIT

if [ -z "$1" ]; then
  BIN_DIR="$HOME/bin"
else
  BIN_DIR="$1"
fi

if [ -z "$MAKESELF" ]; then
  MAKESELF=makeself
fi

if [ "$(uname)" = Darwin ]; then
  STRIP_OPTS="-u"
else
  STRIP_OPTS="--strip-unneeded"
fi

rm -rf _build
echo y | MIX_ENV=prod mix test
MIX_ENV=prod mix release

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -r "$RELEASE_DIR" "$WORK_DIR/rel"

find "$WORK_DIR/rel/erts-"*"/bin" \
     -mindepth 1 -maxdepth 1 -type f \
     -not -regex '.*/beam.smp$' \
     -not -regex '.*/erl$' \
     -not -regex '.*/erl_child_setup$' \
     -not -regex '.*/erlexec$' \
     -not -regex '.*/epmd$' \
     -exec rm -rf {} \;

find "$WORK_DIR/rel" \
     -type f \( -perm -u=x -o -perm -g=x -o -perm -o=x \) \
     -exec chmod +w {} \; \
     -exec strip "$STRIP_OPTS" {} \;

tee "$MAIN_SCRIPT" <<'EOF'
#!/bin/sh

set -e

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

while [ $# -gt 0 ]; do
  case "$1" in
    --check)
      export HOMELANDER_CHECK=1
      shift
      ;;

    --help)
      export HOMELANDER_HELP=1
      shift
      ;;

    --verbose)
      export HOMELANDER_VERBOSE=1
      shift
      ;;

    *)
      export HOMELANDER_CONFIG="$1"
      shift
      ;;
  esac
done

WORKING_DIR="$PWD"
cd "$USER_PWD"
"$WORKING_DIR/bin/homelander" start
EOF
chmod +x "$MAIN_SCRIPT"

"$MAKESELF" \
  --zstd \
  --complevel 19 \
  "$WORK_DIR/rel" \
  "$WORK_DIR/homelander.preupdate" \
  Homelander \
  "$MAIN_SCRIPT_RELATIVE"

(
  < "$WORK_DIR/homelander.preupdate" head -n1
  echo 'set -- --quiet -- "$@"'
  < "$WORK_DIR/homelander.preupdate" tail -n+2 | \
    perl -pe 'if (/^skip="(\d+)"$/) { s/($1)/@{[$1+1]}/ }'
) > "$WORK_DIR/homelander"
chmod +x "$WORK_DIR/homelander"

"$WORK_DIR/homelander" --check

cp "$WORK_DIR/homelander" "$BIN_DIR"
