#!/bin/bash

set -ex

RELEASE_DIR=_build/prod/rel/homelander
WORK_DIR=tmp-makeself

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
MIX_ENV=prod MIX_ESCRIPT_DO_NOT_EMBED_ELIXIR=true mix escript.build
MIX_ENV=prod mix distillery.release

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -r "$RELEASE_DIR" "$WORK_DIR/rel"
cp "$WORK_DIR/rel/erts-"*"/bin/escript" "$WORK_DIR/rel/bin/homelander"

rm -rf "$WORK_DIR/rel/releases"

find "$WORK_DIR/rel/erts-"* \
     -mindepth 1 -maxdepth 1 -type d \
     -not -name bin -and \
     -not -name lib \
     -exec rm -rf {} \;

find "$WORK_DIR/rel/erts-"*"/bin" \
     -mindepth 1 -maxdepth 1 -type f \
     -not -regex '.*/beam.smp$' \
     -not -regex '.*/erl$' \
     -not -regex '.*/erl_child_setup$' \
     -not -regex '.*/erlexec$' \
     -not -regex '.*/inet_gethost$' \
     -exec rm -rf {} \;

find "$WORK_DIR/rel/bin" \
     -mindepth 1 -maxdepth 1 -type f \
     -not -regex '.*/homelander$' \
     -not -regex '.*/homelander.escript$' \
     -not -regex '.*/homelander.sh$' \
     -not -regex '.*/no_dot_erlang.boot$' \
     -exec rm -rf {} \;

find "$WORK_DIR/rel/lib" \
     -mindepth 1 -maxdepth 1 -type d \
     -not -regex '.*/compiler-.*' \
     -not -regex '.*/crypto-.*' \
     -not -regex '.*/elixir-.*' \
     -not -regex '.*/kernel-.*' \
     -not -regex '.*/logger-.*' \
     -not -regex '.*/runtime_tools-.*' \
     -not -regex '.*/sasl-.*' \
     -not -regex '.*/stdlib-.*' \
     -exec rm -rf {} \;

find "$WORK_DIR/rel" \
     -type f \( -perm -u=x -o -perm -g=x -o -perm -o=x \) \
     -exec strip "$STRIP_OPTS" {} \;

mv homelander "$WORK_DIR/rel/bin/homelander.escript"

ERTS_DIR="$(basename "$(find $WORK_DIR/rel -mindepth 1 -maxdepth 1 -type d -name 'erts-*')")"
tee "$WORK_DIR/rel/bin/homelander.sh" <<EOF
#!/bin/sh
TMPDIR="\$PWD"
cd "\$USER_PWD"
env \
  PATH="\$TMPDIR/$ERTS_DIR/bin:\$PATH" \
  LANG=en_US.UTF-8 \
  LC_ALL=en_US.UTF-8 \
  REPLACE_OS_VARS=true \
  "\$TMPDIR/bin/homelander" \
  "\$@"
EOF
chmod +x "$WORK_DIR/rel/bin/homelander.sh"

"$MAKESELF" "$WORK_DIR/rel" "$WORK_DIR/homelander.preupdate" Homelander "./bin/homelander.sh"

(
  < "$WORK_DIR/homelander.preupdate" head -n1
  echo 'set -- --quiet -- "$@"'
  < "$WORK_DIR/homelander.preupdate" tail -n+2 | \
    perl -pe 'if (/^skip="(\d+)"$/) { s/($1)/@{[$1+1]}/ }'
) > "$WORK_DIR/homelander"
chmod +x "$WORK_DIR/homelander"

"$WORK_DIR/homelander" --check

cp "$WORK_DIR/homelander" "$BIN_DIR"
