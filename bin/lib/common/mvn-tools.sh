
JONGO_MAVEN_OPTIONS="--errors --batch-mode -P release -Dsurefire.printSummary=false"

function _mvn() {
    mvn ${JONGO_MAVEN_OPTIONS:-""} $@
}

function append_maven_options() {
    JONGO_MAVEN_OPTIONS="${JONGO_MAVEN_OPTIONS} ${1}"
}

function get_maven_options() {
    echo "${JONGO_MAVEN_OPTIONS}"
}

function configure_deploy_plugin_for_early() {
    append_maven_options "-DaltDeploymentRepository=cloudbees-release::default::dav:https://repository-jongo.forge.cloudbees.com/release"
}

function configure_deploy_plugin_for_test() {
    local base_dir="${1}"
    append_maven_options "-DaltDeploymentRepository=test.repo::default::file:${base_dir}/target/deploy"
}

function configure_maven_gpg_plugin() {
    local gpg_keyname="${1}"
    append_maven_options "-Dgpg.keyname=${gpg_keyname}"
}

function get_pom_content {
    local base_commit="${1}"
    echo "$(git show "${base_commit}:pom.xml")"
}

function get_current_version {
    local base_commit="${1}"
    local pom_xml_content=$(get_pom_content "${base_commit}")

    echo $(echo "${pom_xml_content}" | grep "<artifactId>jongo</artifactId>" -A 1 | grep version | sed -e 's/<[^>]*>//g' | awk '{$1=$1;print}')
}


function set_version {
    local base_branch="${1}"
    local next_version="${2}"

    checkout "${base_branch}"
        _mvn --quiet versions:set -DnewVersion="${next_version}" -DgenerateBackupPoms=false
        git add pom.xml
        git_commit "[release] Set project version to ${next_version}"
    uncheckout
}