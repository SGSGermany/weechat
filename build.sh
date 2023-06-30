#!/bin/bash
# WeeChat
# A container running WeeChat, a open-source Internet Relay Chat (IRC) client.
#
# Copyright (c) 2023  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C.UTF-8

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"
source "$CI_TOOLS_PATH/helper/git.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

WEECHAT_CONFIG="/etc/weechat"
WEECHAT_DATA="/var/lib/weechat"
WEECHAT_CACHE="/var/cache/weechat"
WEECHAT_RUNTIME="/run/weechat"

git_clone "$MERGE_IMAGE_GIT_REPO" "$MERGE_IMAGE_GIT_REF" "$BUILD_DIR/vendor" "./vendor"

con_build --tag "$IMAGE-base" \
    --build-arg VERSION="${VERSION:-latest}" --build-arg SLIM="1" \
    --from "$BASE_IMAGE" --check-from "$MERGE_IMAGE_BASE_IMAGE_PATTERN" \
    "$BUILD_DIR/vendor/$MERGE_IMAGE_BUD_CONTEXT" "./vendor/$MERGE_IMAGE_BUD_CONTEXT"

echo + "CONTAINER=\"\$(buildah from $(quote "$IMAGE-base"))\"" >&2
CONTAINER="$(buildah from "$IMAGE-base")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

cmd buildah config \
    --env HOME- \
    --user root \
    "$CONTAINER"

cmd buildah run "$CONTAINER" -- \
    deluser "user"

echo + "rm -rf …/home/user" >&2
rm -rf "$MOUNT/home/user"

echo + "rm -f …/usr/bin/weechat …/usr/bin/weechat-headless" >&2
rm -f "$MOUNT/usr/bin/weechat" "$MOUNT/usr/bin/weechat-headless"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

pkg_install "$CONTAINER" \
    inotify-tools

user_add "$CONTAINER" weechat 65536 "$WEECHAT_DATA" "/bin/ash"

user_add "$CONTAINER" ssl-certs 65537

cmd buildah run "$CONTAINER" -- \
    adduser weechat ssl-certs

cmd buildah run "$CONTAINER" -- \
    chmod 750 \
        "$WEECHAT_CONFIG" \
        "$WEECHAT_CONFIG/ssl" \
        "$WEECHAT_DATA" \
        "$WEECHAT_CACHE" \
        "$WEECHAT_RUNTIME"

cmd buildah run "$CONTAINER" -- \
    chown -R "weechat":"weechat" \
        "$WEECHAT_CONFIG" \
        "$WEECHAT_DATA" \
        "$WEECHAT_CACHE" \
        "$WEECHAT_RUNTIME"

echo + "VERSION=\"\$(buildah run $(quote "$CONTAINER") -- weechat --version)\"" >&2
VERSION="$(buildah run "$CONTAINER" -- weechat --version)"

echo + "[[ ${VERSION@Q} == $VERSION_PATTERN ]]" >&2
[[ "$VERSION" == $VERSION_PATTERN ]]

cleanup "$CONTAINER"

cmd buildah config \
    --env VERSION- \
    --env SLIM- \
    "$CONTAINER"

cmd buildah config \
    --env WEECHAT_VERSION="$VERSION" \
    "$CONTAINER"

cmd buildah config \
    --env WEECHAT_CONFIG="$WEECHAT_CONFIG" \
    --env WEECHAT_DATA="$WEECHAT_DATA" \
    --env WEECHAT_CACHE="$WEECHAT_CACHE" \
    --env WEECHAT_RUNTIME="$WEECHAT_RUNTIME" \
    "$CONTAINER"

cmd buildah config \
    --volume "$WEECHAT_CONFIG" \
    --volume "$WEECHAT_DATA" \
    --volume "$WEECHAT_CACHE" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "$WEECHAT_DATA" \
    --entrypoint '[ "/entrypoint.sh" ]' \
    --cmd '[ "weechat" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="WeeChat" \
    --annotation org.opencontainers.image.description="A container running WeeChat, a open-source Internet Relay Chat (IRC) client." \
    --annotation org.opencontainers.image.version="$VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/weechat" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
