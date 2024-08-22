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
source "$CI_TOOLS_PATH/helper/git.sh.inc"
source "$CI_TOOLS_PATH/helper/chkeol.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

CYCLE="${1:-}"
if [ -z "$CYCLE" ]; then
    echo "Missing required parameter 'CYCLE'" >&2
    exit 1
fi

GIT_REPO="https://github.com/weechat/weechat.git"

git_ls_tags "$GIT_REPO" \
    | chkeol_versions \
    | chkeol_latest_minor "WeeChat" "$CYCLE" \
    || exit 1

exit 0
