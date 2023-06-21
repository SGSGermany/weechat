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

[ -x "$(which curl)" ] \
    || { echo "Invalid build environment: Missing runtime dependency: curl" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/chkupd.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

TAG="${TAGS%% *}"

# check whether the base image was updated
chkupd_baseimage "$REGISTRY/$OWNER/$IMAGE" "$TAG" || exit 0

# check whether a new stable WeeChat version was released
chkupd_weechat() {
    local IMAGE="$1"
    local VERSION="$2"

    if [ -z "$VERSION" ]; then
        local VERSION_URL="https://weechat.org/dev/info/stable/"

        echo + "VERSION=\"\$(curl -sSL -f -o - $(quote "$VERSION_URL"))\"" >&2
        VERSION="$(curl -sSL -f -o - "$VERSION_URL" || true)"

        if [ -z "$VERSION" ]; then
            echo "Unable to read latest WeeChat version: HTTP request '$VERSION_URL' failed" >&2
            echo "Image rebuild required" >&2
            echo "build"
            return 1
        elif [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?([+~-]|$) ]]; then
            echo "Unable to read latest WeeChat version: HTTP request '$VERSION_URL' returned a malformed response: $(head -n1 <<< "$VERSION")" >&2
            echo "Image rebuild required" >&2
            echo "build"
            return 1
        fi
    fi

    chkupd_image_version "$IMAGE" "$VERSION"
}

chkupd_weechat "$REGISTRY/$OWNER/$IMAGE:$TAG" "${VERSION:-}" || exit 0
