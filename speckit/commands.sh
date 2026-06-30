#!/bin/bash
specify init --here --integration copilot  --integration-options "--skills"
specify extension catalog add https://raw.githubusercontent.com/github/spec-kit/main/extensions/catalog.json --name github-spec-kit --priority 1 --install-allowed --description "GitHub Spec Kit Extensions"
specify extension catalog add https://raw.githubusercontent.com/github/spec-kit/main/extensions/catalog.community.json --name github-spec-kit-community --priority 1 --install-allowed --description "GitHub Spec Kit Community Extensions"
specify extension catalog add https://raw.githubusercontent.com/RbBtSn0w/spec-kit-extensions/main/catalog.json --name rbbtsn0w-spec-kit-extensions --priority 10 --install-allowed --description "RbBtSn0w Spec Kit Extensions"
specify extension catalog add https://github.com/leocamello/spec-kit-v-model/raw/refs/heads/main/catalog-entry.json --name leocamello-spec-kit-v-model --priority 10 --install-allowed --description "Leo Camello Spec Kit V Model"
specify extension add squad
specify extension add v-model
specify extension add superb
specify extension add memorylint
specify extension add fleet
specify extension add companion
specify extension add arch
squad init --no-workflows
# specify extension add harness
# squad init --global

# configure extensions with yq to enable optional features as required