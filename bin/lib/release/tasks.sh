
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/release-tools.sh"

function create_early_release {
    local base_branch="${1}"
    local current_version=$(get_current_version "origin/${base_branch}")
    local early_tag=$(determine_early_release_version "origin/${base_branch}")

    log_task "Creating early release ${early_tag} from branch '${base_branch}'"


    checkout "${base_branch}"
        _mvn verify

        set_version "${base_branch}" "${early_tag}"
        log_info "Branch ${base_branch} updated to project version ${early_tag}"

        local commit_to_tag=$(get_head_commit "${base_branch}")
        git tag "${early_tag}" "${commit_to_tag}"
        log_info "New tag ${early_tag} created refs to ${commit_to_tag}"

        set_version "${base_branch}" "${current_version}"
        log_info "Branch ${base_branch} updated to project version ${current_version}"
    uncheckout

    git push -q origin "${base_branch}"
    git push -q origin "${early_tag}"

    log_success "${early_tag} early version released"

    deploy "${early_tag}"
}

function create_release {
    local base_branch="${1}"
    local hotfix_branch="releases_$(determine_hotfix_version_pattern "origin/${base_branch}")"
    local release_tag=$(determine_release_version "origin/${base_branch}")

    log_task "Creating release ${release_tag} from branch '${base_branch}'"


    checkout -b "${hotfix_branch}" "${base_branch}"
        _mvn verify

        set_version "${hotfix_branch}" "${release_tag}"
        log_info "New branch ${hotfix_branch} created"

        local commit_to_tag=$(get_head_commit "${hotfix_branch}")
        git tag "${release_tag}" "${commit_to_tag}"
        log_info "New tag ${release_tag} created on ${commit_to_tag}"

        bump_to_next_hotfix_snapshot_version "${hotfix_branch}"
        bump_to_next_minor_snapshot_version "${base_branch}"
    uncheckout


    git push -q -u origin "${hotfix_branch}"
    git push -q origin "${release_tag}"
    git push -q origin "${base_branch}"

    log_success "${release_tag} version released"
}

function create_hotfix_release {
    local base_branch="${1}"
    local hotfix_tag=$(determine_release_version "origin/${base_branch}")

    log_task "Creating hotfix release ${hotfix_tag} from branch '${base_branch}'"


    checkout "${base_branch}"
        _mvn verify

        set_version "${base_branch}" "${hotfix_tag}"

        log_info "New branch ${base_branch} updated to project version ${hotfix_tag}"

        local commit_to_tag=$(get_head_commit "${base_branch}")
        git tag "${hotfix_tag}" "${commit_to_tag}"
        log_info "New tag ${hotfix_tag} created refs to ${commit_to_tag}"

        bump_to_next_hotfix_snapshot_version "${base_branch}"
    uncheckout

    git push -q origin "${base_branch}"
    git push -q origin "${hotfix_tag}"

    log_success "${hotfix_tag} hotfix version released"
}

function deploy {
    local tag="${1}"

    log_task "Deploying tag ${tag}..."

    checkout "${tag}"
        _mvn deploy
    uncheckout

    log_success "${tag} deployed into Maven repository"
}

function create_snapshot {
    local base_branch="${1}"

    if [[ ! $(get_current_version ${base_branch}) = *"-SNAPSHOT"* ]]; then
        echo "ci task must be ran against a SNAPSHOT version"
        exit 1
    fi

    checkout "${base_branch}"
        _mvn verify
        deploy "${base_branch}"
    uncheckout
}
