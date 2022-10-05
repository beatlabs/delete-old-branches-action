#!/bin/bash

set -eo pipefail

[[ -n ${INPUT_REPO_TOKEN} ]] || { echo "Please set the REPO_TOKEN input"; exit 1; }
[[ -n ${INPUT_DATE} ]] || { echo "Please specify a suitable date input for branch filtering"; exit 1; }

BASE_URI="https://api.github.com"
REPO="${GITHUB_REPOSITORY}"
DATE=${INPUT_DATE}
GITHUB_TOKEN=${INPUT_REPO_TOKEN}
DRY_RUN=${INPUT_DRY_RUN:-true}
DELETE_TAGS=${INPUT_DELETE_TAGS:-false}
MINIMUM_TAGS=${INPUT_MINIMUM_TAGS:-0}
DEFAULT_BRANCHES=${INPUT_DEFAULT_BRANCHES:-main,master}
EXCLUDE_OPEN_PR_BRANCHES=${INPUT_EXCLUDE_OPEN_PR_BRANCHES:-true}

echo "::set-output name=was_dry_run::${DRY_RUN}"
deleted_branches=()

default_branch_protected() {
    local br=${1}

    local default_branches
    default_branches=$(echo "${DEFAULT_BRANCHES}" | tr "," "\n")

    for default_branch in $default_branches; do
        if [[ "${br}" == "${default_branch}" ]]; then
            return 0
        fi
    done

    return 1
}

branch_protected() {
    local br=${1}

    protected=$(curl -X GET -s -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "${BASE_URI}/repos/${REPO}/branches/${br}" | jq -r .protected)

    # If we got null then something else happened (like no access error etc) so
    # we can't determine the status for the branch
    case ${protected} in
        null) echo "Unable to determine status for branch: ${br}"; return 0 ;;
        true) return 0 ;;
        *) return 1 ;;
    esac
}

extra_branch_or_tag_protected() {
    local br=${1} ref="${2}"

    if [[ "${ref}" == "branch" ]]; then
        echo "${br}" | grep -qiE "${EXCLUDE_BRANCH_REGEX}"
    elif [[ "${ref}" == "tag" ]]; then
        echo "${br}" | grep -qiE "${EXCLUDE_TAG_REGEX}"
    fi

    return $?
}

is_pr_open_on_branch() {
    if [[ "${EXCLUDE_OPEN_PR_BRANCHES}" == false ]]; then
        return 1
    fi

    local br=${1}
    open_prs_branches=$(curl -X GET -s -H "Authorization: token ${GITHUB_TOKEN}" \
        "${BASE_URI}/repos/${REPO}/pulls" | jq '.[].head.ref' | tr -d '"')

    for pr_br in ${open_prs_branches}; do
      if [[ "${pr_br}" == "${br}" ]]; then
          return 0
      fi
    done

    return 1
}

delete_branch_or_tag() {
    local br=${1} ref="${2}" sha="${3}"
    deleted_branches+=("${br}")

    echo "Deleting: ${br}"
    echo "To recreate run: git branch '${br}' '${sha}'"
    if [[ "${DRY_RUN}" == false ]]; then
        status=$(curl -I -X DELETE -o debug.log -s -H "Authorization: Bearer ${GITHUB_TOKEN}" \
                    -w "%{http_code}" "${BASE_URI}/repos/${REPO}/git/refs/${ref}/${br}")

        case ${status} in
            204) ;;
            *)  echo "Deletion of branch ${br} failed with http_status=${status}"
                echo "===== Dumping curl call ====="
                [[ -f debug.log ]] && cat debug.log
                ;;
        esac
    else
        echo "dry-run mode. Nothing changed!"
    fi
}

main() {
    # fetch history etc
    local sha
    git config --global --add safe.directory "${GITHUB_WORKSPACE}"
    git fetch --prune --unshallow --tags
    for br in $(git ls-remote -q --heads --refs | sed "s@^.*heads/@@"); do
        if [[ -z "$(git log --oneline -1 --since="${DATE}" origin/"${br}")" ]]; then
            sha=$(git show-ref -s "origin/${br}")
            default_branch_protected "${br}" && echo "branch: ${br} is a default branch. Won't delete it" && continue
            branch_protected "${br}" && echo "branch: ${br} is likely protected. Won't delete it" && continue
            extra_branch_or_tag_protected "${br}" "branch" && echo "branch: ${br} is explicitly protected and won't be deleted" && continue
            is_pr_open_on_branch "${br}" && echo "branch: ${br} has an open pull request and won't be deleted" && continue
            delete_branch_or_tag "${br}" "heads" "${sha}"
        fi
    done
    echo "::set-output name=deleted_branches::" "${deleted_branches[@]}"
    if [[ "${DELETE_TAGS}" == true ]]; then
        local tag_counter=1
        for br in $(git ls-remote -q --tags --refs | sed "s@^.*tags/@@" | sort -rn); do
            if [[ -z "$(git log --oneline -1 --since="${DATE}" "${br}")" ]]; then
                if [[ ${tag_counter} -gt ${MINIMUM_TAGS} ]]; then
                    extra_branch_or_tag_protected "${br}" "tag" && echo "tag: ${br} is explicitly protected and won't be deleted" && continue
                    delete_branch_or_tag "${br}" "tags"
                else
                    echo "Not deleting tag ${br} due to minimum tag requirement(min: ${MINIMUM_TAGS})"
                    ((tag_counter+=1))
                fi
            fi
        done
    fi
}

main "$@"