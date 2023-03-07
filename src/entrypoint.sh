#!/bin/sh
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

[ $# -gt 0 ] || set -- weechat
if [ "$1" == "weechat" ] || [ "$1" == "weechat-headless" ]; then
    /usr/lib/weechat/weechat-ssl-setup
    /usr/lib/weechat/weechat-ssl-certs-watchdog &

    exec su -p -s /bin/sh weechat -c '"$@"' -- '/bin/sh' "$@"
fi

exec "$@"
