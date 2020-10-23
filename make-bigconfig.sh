#!/bin/bash

set -ex

OUT=bigconfig.txt
FIFO="$OUT.fifo"

rm -f "$FIFO"
mkfifo "$FIFO"

exec 3<>"$FIFO"

CONTENT="$(cat <<'EOF'
    # foo
    (
      # paren comment
      command foo --bar
      foo quux
      env FOO="Bar"
      restart_on (Connection lost|Connection reset)
      cd /bin
    )
EOF
)"

cat <&3 > "$OUT" &

set +x

# shellcheck disable=2034
for i in $(seq 100000); do
  echo "$CONTENT" >&3
done

set -x

exec <&3-

rm "$FIFO"
