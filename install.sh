#!/usr/bin/env bash

# set -e

CONFIG="install.conf.yaml"
DOTBOT_DIR="dotbot"

DOTBOT_BIN="bin/dotbot"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

cd "${BASEDIR}"
git -C "${DOTBOT_DIR}" submodule sync --quiet --recursive
git submodule update --init --recursive "${DOTBOT_DIR}"
"${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" -d "${BASEDIR}" \
    -c "${CONFIG}" "${@}" \
    --plugin-dir dotbot-brew \
    --plugin-dir dotbot-if

# wget https://dot.net/v1/dotnet-install.sh \
#     && chmod +x dotnet-install.sh \
#     && ./dotnet-install.sh --channel LTS \
#     && rm dotnet-install.sh
# wget -qO- https://aka.ms/install-artifacts-credprovider.sh | bash
