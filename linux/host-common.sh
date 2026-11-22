# The shell helpers every capability's host script shares (capabilities/host_verbs.py HOST_COMMON): read before the
# script. The keeper's host helper puts this file before the script on standard input (keeper/host_helper.py); the
# installer ships it beside the script; a script run from the repo reads it from app/capabilities/. Its one copy is
# here. Nothing in it is personal. It defines functions only, and runs nothing.

say() { printf '%s\n' "$*"; }
# A hint for running it by hand, left out when the keeper's helper runs it (--helper).
hint() { [ -n "${HELPER:-}" ] || say "$*"; }
# The part of the command running now, for the helper's STEP lines (a part that dies is `failed`).
PART=""
die() {
    [ -n "${HELPER:-}" ] && [ -n "$PART" ] && say "STEP $PART failed"
    printf '%s\n' "$*" >&2
    exit 2
}
# A reason the keeper words (with --helper), then the words for a person.
refuse() {
    [ -n "${HELPER:-}" ] && say "REASON $1"
    shift
    die "$@"
}
part() { PART=$1; }
# The part done (or `skipped`), as a STEP line for the helper.
part_done() {
    [ -n "${HELPER:-}" ] && [ -n "$PART" ] && say "STEP $PART ${1:-done}"
    PART=""
}
# A command that changes the computer: run, or with --dry-run only said.
act() {
    if [ -n "${DRY_RUN:-}" ]; then
        say "WOULD $*"
        return 0
    fi
    "$@"
}

# Whose a record must be to count: root's (in a --dry-run, HOST_TEST_OWNER stands for root, for the tests).
record_owner() {
    if [ -n "${DRY_RUN:-}" ] && [ -n "${HOST_TEST_OWNER:-}" ]; then
        printf '%s\n' "$HOST_TEST_OWNER"
    else
        printf '0\n'
    fi
}
# Whether each path is root's alone: no link, root's, writable by nobody else.
root_alone() {
    owner=$(record_owner)
    for path in "$@"; do
        [ -e "$path" ] && [ ! -L "$path" ] || return 1
        [ "$(stat -c %u "$path" 2>/dev/null)" = "$owner" ] || return 1
    done
    [ -z "$(find "$@" -maxdepth 0 -perm /022 2>/dev/null)" ]
}
# put_record <folder> <file> <folder mode> <umask> <text>: the record kept, as root, in a folder root alone writes.
# The folder is made (with that mode) when it is missing, and refused when it is a link, someone else's, or writable
# by anyone else. The new file is made there with O_EXCL (noclobber) and its mode from the umask, then moved over the
# old one: nothing is changed by a path another user could have pointed elsewhere.
put_record() {
    record_dir=$1
    record_tmp="$1/.$2.$$"
    if [ ! -e "$record_dir" ] && [ ! -L "$record_dir" ]; then
        mkdir -m "$3" "$record_dir" || return 1
    fi
    [ -d "$record_dir" ] && root_alone "$record_dir" || return 1
    rm -f "$record_tmp"
    if (umask "$4" && set -C && printf '%s\n' "$5" > "$record_tmp") && mv -fT "$record_tmp" "$record_dir/$2"; then
        return 0
    fi
    rm -f "$record_tmp"
    return 1
}
