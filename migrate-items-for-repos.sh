#!/bin/bash

# delete
rm package-lock.json
rm -rf .nuke/
rm -rf .husky/
rm -rf .build/
rm build.*
rm .config/dotnet-tools.json
rm .github/workflows/ci.yml
rm .github/workflows/ci-ignore.yml
rm .github/workflows/publish-nuget.yml

# copy:
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.codecov.yml .codecov.yml
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.editorconfig .editorconfig
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.gitattributes .gitattributes
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.gitignore .gitignore
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.gitmodules .gitmodules
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.prettierignore .prettierignore
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.prettierrc .prettierrc
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/apm.yml apm.yml
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/GitReleaseManager.yaml GitReleaseManager.yaml
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/GitVersion.yml GitVersion.yml
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/global.json global.json
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/LICENSE LICENSE
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/NuGet.config NuGet.config
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/package.json package.json
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/Skillfile Skillfile
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.github/labels.yml .github/labels.yml
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.github/release.yml .github/release.yml
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.github/renovate.json .github/renovate.json
cp -rf /Users/david/Development/RocketSurgeonsGuild/Indago/.apm/ .apm
cp -rf /Users/david/Development/RocketSurgeonsGuild/Indago/.github/workflows/ .github/workflows
cp -rf /Users/david/Development/RocketSurgeonsGuild/Indago/.config/ .config
cp -rf /Users/david/Development/RocketSurgeonsGuild/Indago/build/ build
cp -rf /Users/david/Development/RocketSurgeonsGuild/Indago/docs/ docs
cp -rf /Users/david/Development/RocketSurgeonsGuild/Indago/apm_modules/ apm_modules
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.vscode/extensions.json .vscode/extensions.json
cp -f /Users/david/Development/RocketSurgeonsGuild/Indago/.vscode/tasks.json .vscode/tasks.json

mise trust
mise install
# apm install
# skillfile install
## mise lock

dotnet sln migrate
rm *.sln
rm *.sln.*

# replace template solution name with local .slnx file name
SLNX_FILE="$(find . -maxdepth 1 -type f -name "*.slnx" -print -quit)"
if [[ -n "${SLNX_FILE}" ]]; then
  SLNX_BASENAME="$(basename "${SLNX_FILE}")"

  for target in "hk.pkl" "build/appsettings.yaml"; do
    if [[ -f "${target}" ]]; then
      sed -i '' "s|Indago\\.slnx|${SLNX_BASENAME}|g" "${target}"
    fi
  done
else
  echo "No .slnx file found in repository root; skipping Indago.slnx replacement."
fi