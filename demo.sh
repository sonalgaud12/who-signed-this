#!/usr/bin/env bash
# Live demo driver. Press Enter to advance. Each command is shown before it runs.
#   export IMG=ghcr.io/OWNER/REPO@sha256:...   # digest from the ci-debug run (staged before the talk)
#   export REPO=OWNER/REPO
set -uo pipefail
#   export BRANCH=demo-7                        # branch ci-debug ran on
: "${IMG:?set IMG to the image digest}" "${REPO:?set REPO=owner/repo}" "${BRANCH:?set BRANCH}"

GOOD_ID="https://github.com/${REPO}/.github/workflows/release.yaml@refs/heads/main"
ISSUER="https://token.actions.githubusercontent.com"

step() { echo; echo -e "\033[1;36m## $*\033[0m"; read -r; }
run()  { echo -e "\033[1;33m\$ $*\033[0m"; eval "$@"; }

step "1. The trap: 'cosign verify' passes when you accept ANY identity"
run cosign verify "$IMG" \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' '>/dev/null && echo "✅ signature valid"'

step "2. ...but who signed it?"
run cosign verify "$IMG" --certificate-identity-regexp '.*' --certificate-oidc-issuer-regexp '.*' 2>/dev/null \
  '| jq -r ".[].optional | {Subject, Issuer, githubWorkflowTrigger, githubWorkflowRepository}"'

step "3. Deploy it. Kyverno checks the identity, not just that a signature exists."
run kubectl -n demo run app --image="$IMG" --restart=Never

step "4. Ship it the right way: merge to main, release.yaml rebuilds and signs (same source, same digest)"
run git checkout main '&&' git merge --ff-only "$BRANCH" '&&' git push
sleep 5
run gh run watch '$(gh run list -w release -L1 --json databaseId -q ".[0].databaseId")' --exit-status

step "5. The strict check now passes"
run cosign verify "$IMG" --certificate-identity "$GOOD_ID" --certificate-oidc-issuer "$ISSUER" '>/dev/null && echo "✅ signed by release.yaml@main"'

step "6. Same digest, deployed again: admitted"
run kubectl -n demo run app --image="$IMG" --restart=Never
run kubectl -n demo get pod app -o jsonpath='{.spec.containers[0].image}'; echo

step "7. (Optional) Break glass. ':hotfix' is an UNSIGNED image you pushed before the talk"
run kubectl -n demo run hotfix-1 --image=ghcr.io/${REPO}:hotfix --restart=Never
run kubectl apply -f policy/break-glass.yaml
run kubectl -n demo run hotfix-1 --image=ghcr.io/${REPO}:hotfix --restart=Never
run kubectl get policyexception -n kyverno-exceptions --show-labels

echo; echo "done."
