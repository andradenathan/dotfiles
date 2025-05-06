function git() {
    if [[ $1 = "push" && $# -eq 1 ]]; then
        command git push origin HEAD
    else
        command git "$@"
    fi
}
