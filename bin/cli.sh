#!/usr/bin/env bash

set -euo pipefail

readonly JONGO_BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
source "${JONGO_BASE_DIR}/bin/lib/common/mvn-tools.sh"
source "${JONGO_BASE_DIR}/bin/lib/common/git-tools.sh"
source "${JONGO_BASE_DIR}/bin/lib/common/logger.sh"
source "${JONGO_BASE_DIR}/bin/lib/release.sh"

function usage {
    echo "Usage: $0 [option...] <release|release_early|release_hotfix|deploy_snapshot|deploy|test> <git_revision>"
    echo
    echo "Command line interface to build, package and deploy Jongo"
    echo "Note that by default all tasks are ran in dry mode. Set '--dry-run false' to run it for real. "
    echo
    echo "   --dry-run                  Run task in dry mode. Nothing will be pushed nor deployed (default: true)"
    echo "   --gpg-key                  The GPG key used to sign artifacts (default: contact@jongo.org)"
    echo "   --maven-options            Maven options (eg. '--settings /path/to/settings.xml')"
    echo "   --remote-repository-url    The remote repository url used to clone the project (default https://github.com/bguerout/jongo.git)"
    echo "   --dirty                    Do not clean resources generated during the execution (eg. cloned repository)"
    echo "   --debug                    Print all executed commands and run Maven in debug mode"
    echo
    echo "Usage examples:"
    echo ""
    echo " Release a new version from the master branch:"
    echo ""
    echo "      bash ./bin/cli.sh release master"
    echo ""
    echo " Run a task from inside a docker container:"
    echo ""
    echo "      docker build . -t jongo && docker run -it --volume /path/to/m2/files:/opt/jongo/conf jongo bash -c '<task>'"
    echo ""
}

function configure_dry_mode() {
    local repo_dir="${1}"
    configure_deploy_plugin_for_dry_mode "${repo_dir}"
    update_origin_with_fake_remote "${repo_dir}"
    log_warn "Script is running in dry mode."
}

function safeguard() {
    while true; do
        read -p "[WARN] Do you really want to run this task for real (y/n)?" yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

function __main() {

    local dry_run=true
    local dirty=false
    local remote_repository_url="https://github.com/bguerout/jongo.git"
    local positional=()

    while [[ $# -gt 0 ]]
    do
    key="$1"
    case $key in
        --maven-options)
            append_maven_options "${2}"
            shift
            shift
        ;;
        --remote-repository-url)
            remote_repository_url="${2}"
            shift
            shift
        ;;
        --dirty)
            dirty=true
            log_warn "Dirty mode activated."
            shift
        ;;
        --debug)
            set -x
            append_maven_options "-Dsurefire.printSummary=true"
            shift
        ;;
        -d|--dry-run)
            readonly dry_run="$2"
            shift
            shift
        ;;
        -?|--help)
            usage
            exit 0;
        ;;
        *)
        positional+=("$1")
        shift
        ;;
    esac
    done
    set -- "${positional[@]}"

    local task="${1}"
    local git_revision="${2:-$(git rev-parse --abbrev-ref HEAD)}"

    [[ "${dirty}" = false ]] &&  trap clean_resources EXIT

    local repo_dir=$(clone_repository "${remote_repository_url}")
    [[ "${dry_run}" = true ]] &&  configure_dry_mode "${repo_dir}" || safeguard

    pushd "${repo_dir}" > /dev/null
        case "${task}" in
            test)
                source "${JONGO_BASE_DIR}/src/test/sh/release/release-tests.sh"
                run_test_suite "${git_revision}" "${repo_dir}"
            ;;
            release_early)
                [[ "${dry_run}" = false ]] && configure_deploy_plugin_for_early
                create_early_release "${git_revision}"
            ;;
            release)
                create_release "${git_revision}"
            ;;
            release_hotfix)
                create_hotfix_release "${git_revision}"
            ;;
            deploy)
                [[ "${dry_run}" = false && "${git_revision}" = *"-early-"* ]] &&  configure_deploy_plugin_for_early
                deploy "${git_revision}"
            ;;
            deploy_snapshot)
                deploy_snapshot "${git_revision}"
            ;;
            *)
             log_error "Unknown task '${task}'"
             usage
             exit 1;
            ;;
        esac
    popd > /dev/null
}

__main "$@"