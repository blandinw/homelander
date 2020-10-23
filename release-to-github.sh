#!/usr/bin/env bash

set -ex

usage() {
    echo "$(basename "$0") <version> <gh-username> <gh-token> [existing-release-id]"
    exit 1
}

if [ $# -lt 3 ]; then
    usage
fi

VERSION="$1"
shift
GITHUB_USERNAME="$1"
shift
GITHUB_TOKEN="$1"
shift
RELEASE_ID="$1"
WORK_DIR="tmp-release"

if [ -z "$RELEASE_ID" ]; then
  if ! which jq; then
    echo 'you need jq -- brew install jq or http://stedolan.github.io/jq/'
    exit 1
  fi
fi

cleanup () {
  rm -rf "$WORK_DIR"
  true
}
trap cleanup ERR EXIT

mkdir -p "$WORK_DIR"

archive() (
  ARCH="$1"
  RELEASE_DIR="homelander-$ARCH"
  TAR="$RELEASE_DIR.tar.gz"

  cd "$WORK_DIR"

  # create archive
  rm -rf "$RELEASE_DIR"
  mkdir -p "$RELEASE_DIR"
  mv homelander "$RELEASE_DIR"
  tar czvf "$TAR" "$RELEASE_DIR"
)

upload() (
  ARCH="$1"
  RELEASE_DIR="homelander-$ARCH"
  TAR="$RELEASE_DIR.tar.gz"

  cd "$WORK_DIR"

  # upload asset
  curl "https://uploads.github.com/repos/blandinw/homelander/releases/$RELEASE_ID/assets?name=$TAR" \
       -XPOST \
       --fail \
       -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" \
       -H 'Content-Type: application/gzip' \
       --data-binary "@$TAR"
)

./install-makeself.sh "$WORK_DIR" && archive "x86_64-macos"

docker run \
       --rm -it -v "$PWD:/app" --entrypoint /bin/sh elixir -c \
       'cd /app && export MAKESELF=$PWD/makeself-2.4.2/makeself.sh && ./install-makeself.sh '"$WORK_DIR" && \
       archive "x86_64-linux-gnu"

docker run \
       --rm -it -v "$PWD:/app" --entrypoint /bin/sh elixir:alpine -c \
       'apk add bash tar perl binutils curl && cd /app && export MAKESELF=$PWD/makeself-2.4.2/makeself.sh && ./install-makeself.sh '"$WORK_DIR" && \
       archive "x86_64-linux-musl"

if [ -z "$RELEASE_ID" ]; then
  # create release
  CURL_OUT="$(
      curl https://api.github.com/repos/blandinw/homelander/releases \
      -XPOST \
      --fail \
      -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" \
      -d '{
        "tag_name": "'"$VERSION"'",
        "name": "'"$VERSION"'"
      }'
  )"
  RELEASE_ID="$(echo "$CURL_OUT" | jq --raw-output '.id')"
fi

upload "x86_64-macos"
upload "x86_64-linux-gnu"
upload "x86_64-linux-musl"
