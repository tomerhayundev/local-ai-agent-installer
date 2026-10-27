#!/bin/bash
# The phone line on this computer (Linux): packages, Bluetooth and audio settings, pairing the phone, a check, and a
# test call with no AI. Run it with sudo from your own user, in a terminal on this computer:
#
#   sudo bash phone-line.sh setup               once: installs and configures everything (safe to run again)
#   sudo bash phone-line.sh pair                pairs the phone (3 minutes) and prints its address
#   sudo bash phone-line.sh check               prints "ok <address> <name>" when oFono has the phone's modem
#   sudo bash phone-line.sh status              what is done already (setup ready or needed, the paired and the
#                                               connected phones, the line's AppArmor profile); it changes nothing
#   sudo bash phone-line.sh test-call <number>  dials your own number, plays a tone, listens 5 s, hangs up
#   sudo bash phone-line.sh unpair <address>    undoes that phone's pairing (on --adapter, default hci0)
#   (line-up, with --helper only: the keeper brings the line's compose up, as its user, never pulling; line-down and
#   undo-setup, with --helper only: the keeper takes the line down, and undoes what setup changed, when no agent on
#   the computer has the phone any more)
#
# The keeper runs it for an agent's page (its phone install, a new phone, a removal: see --helper below); run by hand,
# each command does only its own part. Setup, check and the test call were
# proven on a real Ubuntu server (oFono as the hands-free backend, PipeWire for the audio); pairing is phone-line-pair.py,
# which sits next to this file, and so does phone-line.apparmor, the line container's AppArmor profile (setup installs
# it on a computer with AppArmor). Nothing in it is personal: the phone's
# address and the numbers are what you type or what the pairing prints, and they stay on this computer.
#
# Its one copy is app/capabilities/phone/host/ in the repo, so it is in the agent's image; the Linux zip ships it next to
# install-agent.sh. The keeper runs it from its own image, for an agent's page, through the host helper
# (app/keeper/host_helper.py), with these options after the command:
#   --helper --user <uid> --files <dir>   the user the line runs as is the one with that uid (getent passwd, never
#                                         SUDO_USER), the sibling files are in <dir> (the script itself comes on standard
#                                         input), the hints are left out, and machine lines are added for the keeper:
#                                         `STEP <part> done|skipped|failed`, `REASON <id>` (no_apt, no_adapter,
#                                         rootless_docker) and, from status, `adapter <hciN>` for each adapter
#   --home <dir>                          (setup, line-up and undo-setup, with --helper) the agents home on this
#                                         computer: setup keeps what it changed in <dir>/keeper/host/host_setup.json
#                                         (see setup_record), and undo-setup reads it from there; line-up starts
#                                         <dir>/keeper/line/compose.yml (the keeper's own, never one in the line's
#                                         folder)
#   --answers <dir>                       (pair, with --helper: needed there) the job's exchange folder: the pairing
#                                         agent asks the keeper's page through it instead of a terminal
#   --adapter <hciN>                      (pair, unpair) the Bluetooth adapter to pair on (default: the first), or
#                                         the one the phone is paired on (default: hci0)
#   --dry-run                             (setup, status, pair, line-up, line-down, unpair and undo-setup) says
#                                         `WOULD <action>` for each change and makes none
set -u

PACKAGES="bluez ofono pipewire pipewire-bin wireplumber libspa-0.2-bluetooth"
PAIR_PACKAGES="python3-dbus python3-gi"      # for phone-line-pair.py, the pairing agent
PAIR_SECONDS=180
CALL_RING_SECONDS=45
RECORD_SECONDS=5

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
part_done() {
    [ -n "${HELPER:-}" ] && [ -n "$PART" ] && say "STEP $PART done"
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

need_root() {
    [ -n "${DRY_RUN:-}" ] && return 0
    [ "$(id -u)" = 0 ] || die "Run it with sudo: sudo bash $0 $COMMAND"
}

# The user the line runs as: the one who typed sudo, or with --helper the one whose uid the keeper gave (the keeper's own
# user). Its PipeWire, its D-Bus policy, its linger.
need_user() {
    if [ -n "${HELPER:-}" ]; then
        entry=$(getent passwd "$HELPER_UID") || die "There is no user with the id $HELPER_UID."
        TARGET_USER=$(printf '%s\n' "$entry" | cut -d: -f1)
        TARGET_UID=$(printf '%s\n' "$entry" | cut -d: -f3)
        TARGET_HOME=$(printf '%s\n' "$entry" | cut -d: -f6)
        [ "$TARGET_UID" = "$HELPER_UID" ] && [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != root ] \
            || die "The phone line runs as the keeper's own user, never root."
    else
        TARGET_USER=${SUDO_USER:-}
        [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != root ] || die "Run it with sudo from your own user (not from root's own shell): the phone line runs as that user."
        TARGET_UID=$(id -u "$TARGET_USER") || die "There is no user $TARGET_USER."
        TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    fi
    [ -n "$TARGET_HOME" ] && [ -d "$TARGET_HOME" ] || die "The home folder of $TARGET_USER could not be found."
    [ -z "${DRY_RUN:-}" ] || say "WOULD act for the user $TARGET_USER"
}

# A command as the target user, with its PipeWire and user systemd reachable.
as_user() {
    runuser -u "$TARGET_USER" -- env XDG_RUNTIME_DIR=/run/user/$TARGET_UID "$@"
}

# Whether every one of these commands is there (for status, which only looks).
have_commands() {
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || return 1
    done
}

need_commands() {
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || die "$tool is missing: run 'sudo bash $0 setup' first."
    done
}

# ---- setup -------------------------------------------------------------------------------------------------------------

# oFono (2.18) was seen to crash (SIGABRT) when the phone connected again, and then no call could go until it was
# started by hand. A systemd drop-in, kept apart from the package's own unit, starts it again 2 s after it stops on an
# error. It is written only when missing or different (a run again changes nothing); systemd then reloads its units.
# It never restarts oFono itself: that would drop a phone kept connected.
OFONO_DROPIN_DIR=/etc/systemd/system/ofono.service.d
OFONO_DROPIN="[Service]
Restart=on-failure
RestartSec=2"
ofono_restarts() {
    file="$1/phone-line.conf"
    [ "$(cat "$file" 2>/dev/null)" = "$OFONO_DROPIN" ] && return 0
    mkdir -p "$1" || return 1
    printf '%s\n' "$OFONO_DROPIN" > "$file" || return 1
    systemctl daemon-reload
}

# The line container's AppArmor profile. On a computer with AppArmor, Docker puts every container under its
# docker-default profile, and on Ubuntu that one denies every D-Bus call, which the line needs for BlueZ and oFono. So the
# line runs under its own: phone-line.apparmor (next to this script), docker-default's rules plus only the D-Bus calls
# the line makes. setup copies it to /etc/apparmor.d (AppArmor loads that folder again at every boot) and loads it with
# apparmor_parser, both only when something differs (a run again changes nothing). status says `apparmor <name>` while it
# is loaded; the keeper passes that on to the line's compose, which then names the profile. A computer without
# AppArmor (or without apparmor_parser, which Docker needs as well to confine anything) gets no profile: Docker applies
# none there.
APPARMOR_PROFILE=local-ai-agent-phone-line
# APPARMOR_SOURCE is phone-line.apparmor in HERE (next to this script, or the helper's --files): set by main.
APPARMOR_DIR=/etc/apparmor.d
APPARMOR_ENABLED=/sys/module/apparmor/parameters/enabled
APPARMOR_LOADED=/sys/kernel/security/apparmor/profiles

apparmor_on() {
    [ "$(cat "$APPARMOR_ENABLED" 2>/dev/null)" = Y ] && command -v apparmor_parser >/dev/null 2>&1
}

# Whether the kernel has the line's profile, enforced.
apparmor_loaded() {
    grep -qxF "$APPARMOR_PROFILE (enforce)" "$APPARMOR_LOADED" 2>/dev/null
}

# Whether the profile in /etc/apparmor.d is this script's own, and loaded.
apparmor_ready() {
    cmp -s "$APPARMOR_SOURCE" "$APPARMOR_DIR/$APPARMOR_PROFILE" && apparmor_loaded
}

apparmor_install() {
    apparmor_on || return 0
    [ -f "$APPARMOR_SOURCE" ] || die "phone-line.apparmor is missing: it belongs next to phone-line.sh."
    target="$APPARMOR_DIR/$APPARMOR_PROFILE"
    changed=""
    if ! cmp -s "$APPARMOR_SOURCE" "$target"; then
        cp "$APPARMOR_SOURCE" "$target" && chmod 644 "$target" || return 1
        changed=1
    fi
    if [ -n "$changed" ] || ! apparmor_loaded; then
        apparmor_parser -r "$target" || return 1          # -r: replaces the loaded profile, or adds it
    fi
}

# The two files setup writes from here: WirePlumber's drop-in, and the D-Bus policy for the line's user.
wireplumber_conf() {
    cat <<'EOF'
monitor.bluez.properties = {
  bluez5.hfphsp-backend = "ofono"
  bluez5.roles = [ hfp_hf ]
}
EOF
}

dbus_policy() {
    cat <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="$TARGET_USER">
    <allow send_destination="org.ofono"/>
  </policy>
</busconfig>
EOF
}

# Standard input into a file, as the line's user, or as root.
put_as_user() { as_user tee "$1" >/dev/null; }
put_as_root() { cat > "$1"; }

# What setup changed on this computer, so that it can be undone later (with --home; the keeper reads it):
# <home>/keeper/host/host_setup.json, mode 644,
#   {"packages": [the packages that were missing and that it installed], "linger_was_off": true|false,
#    "files": [the files it writes]}
# written before setup changes anything else and again at its end. A package already on the computer is never listed.
# It lives in the keeper's own folder, in a folder `host` that root alone writes: never under phone-line, which the
# line's container writes (its /data), and never mounted into an agent or the line, because a later undo-setup, as
# root, removes what it lists. An earlier record counts only when it is root's own (record_trusted), and then only the
# names of this script's own packages are carried over from it (with its linger).
SETUP_RECORD=host_setup.json
package_present() {
    # ${Status} is dpkg-query's own field, not the shell's:
    # shellcheck disable=SC2016
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}
# The record's folder and file.
record_folder() { printf '%s\n' "$SETUP_HOME/keeper/host"; }
# Whose a record must be to count: root's (in a --dry-run, PHONE_LINE_TEST_OWNER stands for root, for the tests).
record_owner() {
    if [ -n "${DRY_RUN:-}" ] && [ -n "${PHONE_LINE_TEST_OWNER:-}" ]; then
        printf '%s\n' "$PHONE_LINE_TEST_OWNER"
    else
        printf '0\n'
    fi
}
# Whether a folder (and a file in it) is root's alone: no link, root's, writable by nobody else.
root_alone() {
    owner=$(record_owner)
    for path in "$@"; do
        [ -e "$path" ] && [ ! -L "$path" ] || return 1
        [ "$(stat -c %u "$path" 2>/dev/null)" = "$owner" ] || return 1
    done
    [ -z "$(find "$@" -maxdepth 0 -perm /022 2>/dev/null)" ]
}
record_trusted() {
    [ -d "$(record_folder)" ] && [ -f "$1" ] && root_alone "$(record_folder)" "$1"
}
# The packages of an earlier record, one a line: only names of this script's own packages.
record_packages() {
    for package in $(sed -n 's/.*"packages": \[\([^]]*\)\].*/\1/p' "$1" 2>/dev/null | tr -d '" ' | tr ',' ' '); do
        case " $PACKAGES $PAIR_PACKAGES " in *" $package "*) say "$package" ;; esac
    done
}
json_text() { printf '"%s"' "$(printf '%s' "$1" | sed 's/[\\"]/\\&/g')"; }
json_list() {
    out=""
    for item in "$@"; do
        out="${out:+$out, }$(json_text "$item")"
    done
    printf '[%s]' "$out"
}
# The files setup writes, one a line.
setup_files() {
    say "$OFONO_DROPIN_DIR/phone-line.conf"
    apparmor_on && say "$APPARMOR_DIR/$APPARMOR_PROFILE"
    say "$TARGET_HOME/.config/wireplumber/wireplumber.conf.d/51-phone-line.conf"
    say "/etc/dbus-1/system.d/ofono-phone-line.conf"
}
setup_record() {
    before="$(record_folder)/$SETUP_RECORD"
    packages=""
    trusted=""
    if record_trusted "$before"; then
        trusted=1
        packages=$(record_packages "$before" | tr '\n' ' ')
    fi
    for package in $PACKAGES $PAIR_PACKAGES; do
        case " $packages " in *" $package "*) continue ;; esac
        package_present "$package" || packages="$packages $package"
    done
    if [ -n "$trusted" ] && grep -q '"linger_was_off": ' "$before" 2>/dev/null; then
        if grep -q '"linger_was_off": true' "$before"; then linger=true; else linger=false; fi
    elif [ "$(loginctl show-user "$TARGET_USER" -p Linger --value 2>/dev/null)" = yes ]; then
        linger=false
    else
        linger=true
    fi
    files=$(setup_files)
    set -f
    # one word a package:
    # shellcheck disable=SC2086
    set -- $packages
    list=$(json_list "$@")
    old_ifs=$IFS
    IFS='
'
    # one line a file:
    # shellcheck disable=SC2086
    set -- $files
    IFS=$old_ifs
    set +f
    printf '{"packages": %s, "linger_was_off": %s, "files": %s}' "$list" "$linger" "$(json_list "$@")"
}
# The record kept, as root, in a folder root alone writes: <home>/keeper/host is made by root (mode 755) when it is
# missing, and refused when it is a link, someone else's, or writable by anyone else. The new file is made there with
# O_EXCL (noclobber) and its mode from the umask (644), then moved over the old one: nothing is changed by a path
# another user could have pointed elsewhere.
put_record() {
    keeper="$SETUP_HOME/keeper"
    folder=$(record_folder)
    [ -d "$keeper" ] && [ ! -L "$keeper" ] || return 1
    if [ ! -e "$folder" ] && [ ! -L "$folder" ]; then
        mkdir -m 755 "$folder" || return 1
    fi
    [ -d "$folder" ] && root_alone "$folder" || return 1
    tmp="$folder/.$SETUP_RECORD.$$"
    rm -f "$tmp"
    if (umask 022 && set -C && printf '%s\n' "$1" > "$tmp") && mv -fT "$tmp" "$folder/$SETUP_RECORD"; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}
keep_record() {
    [ -n "${SETUP_HOME:-}" ] || return 0
    record=$(setup_record)
    if [ -n "${DRY_RUN:-}" ]; then
        say "WOULD record $(record_folder)/$SETUP_RECORD $record"
    else
        put_record "$record" || die "What setup changes could not be recorded in $(record_folder) (it must be root's alone)."
    fi
}

setup() {
    need_root
    need_user
    part packages
    command -v apt-get >/dev/null 2>&1 || refuse no_apt "setup uses apt (Ubuntu or Debian). Install these yourself: $PACKAGES"
    keep_record
    say "Installing: $PACKAGES $PAIR_PACKAGES"
    act apt-get update -qq || die "apt could not update its lists."
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive act apt-get install -y --no-install-recommends $PACKAGES $PAIR_PACKAGES || die "The packages could not be installed."
    act rfkill unblock bluetooth 2>/dev/null || true
    part_done
    part ofono
    say "oFono: it starts again by itself when it stops on an error."
    act ofono_restarts "$OFONO_DROPIN_DIR" || die "The oFono setting could not be written."
    act systemctl enable --now bluetooth ofono || die "bluetooth and ofono could not be started."
    part_done
    if apparmor_on; then
        part apparmor
        say "AppArmor: the phone line's container gets its own profile ($APPARMOR_PROFILE)."
        act apparmor_install || die "The phone line's AppArmor profile could not be installed and loaded (above is why)."
        part_done
    fi

    part linger
    say "Turning on linger for $TARGET_USER, so PipeWire runs without a login."
    act loginctl enable-linger "$TARGET_USER" || die "linger could not be turned on."
    act systemctl start "user@$TARGET_UID.service" 2>/dev/null || true
    if [ -z "${DRY_RUN:-}" ]; then
        waited=0
        while [ ! -d "/run/user/$TARGET_UID" ] && [ "$waited" -lt 30 ]; do
            sleep 1
            waited=$((waited + 1))
        done
        [ -d "/run/user/$TARGET_UID" ] || die "/run/user/$TARGET_UID did not appear: the user's systemd is not running."
    fi
    part_done
    part pipewire
    act as_user systemctl --user enable --now pipewire.socket pipewire.service wireplumber.service || die "PipeWire and WirePlumber could not be started for $TARGET_USER."
    part_done

    part wireplumber
    say "WirePlumber: oFono carries the hands-free profile, and this computer is only a hands-free unit."
    dropin="$TARGET_HOME/.config/wireplumber/wireplumber.conf.d"
    act as_user mkdir -p "$dropin" || die "$dropin could not be made."
    wireplumber_conf | act put_as_user "$dropin/51-phone-line.conf" || die "The WirePlumber settings could not be written."
    part_done

    part dbus
    say "D-Bus: $TARGET_USER may talk to oFono."
    dbus_policy | act put_as_root /etc/dbus-1/system.d/ofono-phone-line.conf || die "The D-Bus policy could not be written."
    act systemctl reload dbus || die "D-Bus could not reload its policy."
    act as_user systemctl --user restart wireplumber || die "WirePlumber could not restart."
    part_done

    keep_record
    say "Setup done."
    hint "Next: sudo bash $0 pair"
}

# ---- pair --------------------------------------------------------------------------------------------------------------

# The addresses of the paired devices, one a line, sorted (used by check).
paired_devices() {
    list=$(timeout --foreground 5 bluetoothctl devices Paired 2>/dev/null)
    [ -n "$list" ] || list=$(timeout --foreground 5 bluetoothctl paired-devices 2>/dev/null)
    printf '%s\n' "$list" | sed -n 's/^Device \([0-9A-Fa-f:]\{17\}\).*/\1/p' | sort
}

# The name BlueZ has for a device, as the device gave it: only the printable characters are kept, so nothing in it can
# act on the terminal it is shown on.
device_name() {
    timeout --foreground 5 bluetoothctl info "$1" 2>/dev/null | sed -n 's/^[[:space:]]*Name: //p' | head -n 1 | LC_ALL=C tr -cd '[:print:]' | cut -c1-40
}

# The pairing itself is phone-line-pair.py, a small BlueZ agent over D-Bus (next to this script): it names the asking
# device from BlueZ's own object path, shows its name (cleaned) and the passkey, accepts one typed "yes" for exactly that
# request, refuses the rest, and turns pairable and discoverable off when the phone has paired or the window ends.
# For the keeper (--helper) the agent asks the page through the job's exchange folder (--answers), never a terminal.
pair() {
    need_root
    need_user
    part pair
    [ -z "${HELPER:-}" ] || [ -n "$ANSWERS" ] || die "--helper pair needs --answers and the job's folder."
    agent="$HERE/phone-line-pair.py"
    if [ -n "${DRY_RUN:-}" ]; then
        say "WOULD python3 -I $agent $PAIR_SECONDS${ANSWERS:+ --answers $ANSWERS}${ADAPTER:+ --adapter $ADAPTER}"
        part_done
        return 0
    fi
    need_commands python3 timeout
    systemctl is-active --quiet bluetooth || die "Bluetooth is not running: run 'sudo bash $0 setup' first."
    python3 -I -c 'import dbus, gi' 2>/dev/null || die "python3-dbus and python3-gi are missing: run 'sudo bash $0 setup' first."
    [ -f "$agent" ] || die "phone-line-pair.py is missing: it belongs next to phone-line.sh."
    extra=()
    [ -z "$ANSWERS" ] || extra+=(--answers "$ANSWERS")
    [ -z "$ADAPTER" ] || extra+=(--adapter "$ADAPTER")
    # The agent keeps to its own window; this is only the last word if it hangs (TERM first, then KILL).
    timeout --foreground -k 10 $((PAIR_SECONDS + 30)) python3 -I "$agent" "$PAIR_SECONDS" "${extra[@]}"
    code=$?
    # Whatever happened to the agent, the adapter does not stay open for pairing.
    timeout --foreground 5 bluetoothctl discoverable off >/dev/null 2>&1
    timeout --foreground 5 bluetoothctl pairable off >/dev/null 2>&1
    if [ "$code" != 0 ]; then
        [ -z "${HELPER:-}" ] || say "STEP pair failed"
        exit "$code"
    fi
    part_done
    hint "Then run: sudo bash $0 check"
}

# ---- check -------------------------------------------------------------------------------------------------------------

# The modems oFono has for phones (/hfp/... paths with a VoiceCallManager), one a line, or nothing.
find_modem() {
    # As the user the line runs as: this proves the D-Bus policy, which root's own access would hide.
    as_user dbus-send --system --print-reply --dest=org.ofono / org.ofono.Manager.GetModems 2>/dev/null | awk '
        /object path "/ { path = $0; sub(/.*object path "/, "", path); sub(/".*/, "", path) }
        /org\.ofono\.VoiceCallManager/ { if (path ~ /^\/hfp\//) found[path] = 1 }
        END { for (p in found) print p }'
}

# The phone's address in a modem's path (/hfp/org/bluez/hci0/dev_AA_BB_...).
modem_address() {
    printf '%s\n' "$1" | sed 's/.*dev_//; s/_/:/g'
}

# With an address (the keeper gives the phone's), only that phone's modem counts, and only it is asked to connect:
# another phone in reach is never taken for it. Without one, the first modem, and every paired device is asked.
check() {
    need_root
    need_user
    part modem
    need_commands dbus-send bluetoothctl
    want=$(printf '%s' "${1:-}" | tr 'abcdef' 'ABCDEF')
    case "$want" in
        "") ;;
        [0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]) ;;
        *) die "Usage: sudo bash $0 check [the phone's address]" ;;
    esac
    modem=""
    tried=0
    waited=0
    while [ "$waited" -lt 30 ]; do
        if [ -n "$want" ]; then
            modem=$(find_modem | grep "/dev_$(printf '%s' "$want" | tr ':' '_')\$" | head -n 1)
        else
            modem=$(find_modem | head -n 1)
        fi
        [ -n "$modem" ] && break
        if [ "$tried" = 0 ]; then
            tried=1
            # The phone connects the hands-free profile by itself once paired; ask it to, in case it has not.
            for address in ${want:-$(paired_devices)}; do
                timeout --foreground 10 bluetoothctl connect "$address" >/dev/null 2>&1
            done
        fi
        sleep 2
        waited=$((waited + 2))
    done
    if [ -z "$modem" ]; then
        say "not ready: oFono has no modem for the phone. Is the phone near, its Bluetooth on, and is it paired (sudo bash $0 pair)?"
        [ -z "${HELPER:-}" ] || say "STEP modem failed"
        exit 1
    fi
    address=$(modem_address "$modem")
    name=$(device_name "$address")
    say "ok $address ${name:-}"
    part_done
}

# ---- status ------------------------------------------------------------------------------------------------------------

# What is done on this computer already, one fact a line, for the keeper (it does only what is missing). It changes
# nothing:
#   setup ready | setup needed   all that `setup` does: the packages, Bluetooth and oFono running, linger, the user's
#                                PipeWire socket, the WirePlumber settings, the D-Bus policy for the user and oFono's
#                                drop-in that starts it again (a computer set up before it gets it on the next run),
#                                and on a computer with AppArmor the line's profile, installed and loaded
#   paired <address>             each device BlueZ has paired
#   modem <address>              each phone oFono has a hands-free modem for (paired, and in reach now)
#   apparmor <profile>           the line's AppArmor profile is loaded (only on a computer with AppArmor; there,
#                                setup ready includes it, as this script ships it)
# With --helper, also the machine lines of host_facts.
status() {
    need_root
    need_user
    ready=yes
    have_commands bluetoothctl dbus-send busctl pw-cli pw-play pw-record python3 timeout runuser loginctl || ready=no
    python3 -I -c 'import dbus, gi' 2>/dev/null || ready=no
    systemctl is-active --quiet bluetooth || ready=no
    systemctl is-active --quiet ofono || ready=no
    [ "$(loginctl show-user "$TARGET_USER" -p Linger --value 2>/dev/null)" = yes ] || ready=no
    [ -S "/run/user/$TARGET_UID/pipewire-0" ] || ready=no
    grep -qF 'bluez5.hfphsp-backend = "ofono"' "$TARGET_HOME/.config/wireplumber/wireplumber.conf.d/51-phone-line.conf" 2>/dev/null || ready=no
    grep -qF "<policy user=\"$TARGET_USER\">" /etc/dbus-1/system.d/ofono-phone-line.conf 2>/dev/null || ready=no
    [ "$(cat "$OFONO_DROPIN_DIR/phone-line.conf" 2>/dev/null)" = "$OFONO_DROPIN" ] || ready=no
    if apparmor_on; then
        apparmor_ready || ready=no
    fi
    if [ "$ready" = yes ]; then
        say "setup ready"
    else
        say "setup needed"
    fi
    if have_commands bluetoothctl timeout && systemctl is-active --quiet bluetooth; then
        for address in $(paired_devices); do
            say "paired $address"
        done
    fi
    if [ "$ready" = yes ]; then
        for modem in $(find_modem); do
            say "modem $(modem_address "$modem")"
        done
    fi
    if apparmor_on && apparmor_loaded; then
        say "apparmor $APPARMOR_PROFILE"
    fi
    [ -z "${HELPER:-}" ] || host_facts "$ready"
}

# What the keeper's page says before any click (with --helper), from looking only:
#   adapter <hciN>          each Bluetooth adapter the kernel has (/sys/class/bluetooth)
#   REASON no_adapter       none
#   REASON no_apt           setup is needed and there is no apt to do it with (not Ubuntu or Debian)
#   REASON rootless_docker  Docker runs rootless for the line's user, with no Docker of the system's: the line's container
#                           could not reach the computer's Bluetooth
# In a --dry-run, PHONE_LINE_TEST_ROOT (a test's folder) stands for / in these looks only.
host_facts() {
    root=""
    [ -z "${DRY_RUN:-}" ] || root=${PHONE_LINE_TEST_ROOT:-}
    found=""
    for adapter in "$root"/sys/class/bluetooth/hci*; do
        name=${adapter##*/}
        case "$name" in
            hci[0-9]|hci[0-9][0-9]) [ -e "$adapter" ] && say "adapter $name" && found=1 ;;
        esac
    done
    [ -n "$found" ] || say "REASON no_adapter"
    if [ "$1" != yes ] && ! command -v apt-get >/dev/null 2>&1; then
        say "REASON no_apt"
    fi
    if [ -e "$root/run/user/$TARGET_UID/docker.sock" ] && [ ! -e "$root/run/docker.sock" ] && [ ! -e "$root/var/run/docker.sock" ]; then
        say "REASON rootless_docker"
    fi
}

# ---- line-up -----------------------------------------------------------------------------------------------------------

# The keeper's line_up (the phone install's, and the line following the keeper's release): the line's compose file,
# which the keeper rendered just before in its own folder (keeper/line/, mounted into no container: never a file the
# line could have written), brought up as the line's user with that user's own Docker access, and never pulling (the
# image is the keeper's own, on this computer already). Root only checks that the file is there; the user reads it.
line_up() {
    part line_up
    need_root
    need_user
    [ -n "$SETUP_HOME" ] || die "line-up needs --home and the agents home on this computer."
    compose_file="$SETUP_HOME/keeper/line/compose.yml"
    [ -f "$compose_file" ] && [ ! -L "$compose_file" ] || die "The keeper has written no compose file for the phone line in $SETUP_HOME/keeper/line."
    act as_user docker compose -f "$compose_file" up -d --pull never < /dev/null || die "Docker could not start the phone line."
    part_done
}

# ---- removal: line-down, unpair, undo-setup (with --helper: the keeper, when the phone is removed) -----------------

# The line's container stopped and removed, by its Compose project's name: no compose file is read, so nothing the
# line could have written decides what runs. As the line's user, with that user's own Docker access, like line-up.
LINE_PROJECT=phone-line
line_down() {
    part line_down
    need_root
    need_user
    act as_user docker compose -p "$LINE_PROJECT" down < /dev/null || die "Docker could not stop the phone line."
    part_done
}

# One phone's pairing undone: the device removed from the adapter it is paired on (--adapter, default hci0), over
# BlueZ's D-Bus. A phone this computer does not have paired is no failure (`STEP unpair skipped`).
unpair() {
    part unpair
    need_root
    want=$(printf '%s' "${1:-}" | tr 'abcdef' 'ABCDEF')
    case "$want" in
        [0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]) ;;
        *) die "Usage: sudo bash $0 unpair <the phone's address> [--adapter hciN]" ;;
    esac
    adapter=${ADAPTER:-hci0}
    device="/org/bluez/$adapter/dev_$(printf '%s' "$want" | tr ':' '_')"
    if [ -z "${DRY_RUN:-}" ]; then
        need_commands busctl
        if ! busctl --system get-property org.bluez "$device" org.bluez.Device1 Address >/dev/null 2>&1; then
            say "$want is not paired on $adapter: nothing to undo."
            [ -z "${HELPER:-}" ] || say "STEP unpair skipped"
            PART=""
            return 0
        fi
    fi
    act busctl --system call org.bluez "/org/bluez/$adapter" org.bluez.Adapter1 RemoveDevice o "$device" \
        || die "The phone's pairing could not be removed."
    part_done
}

# What setup changed, undone, when no agent on the computer has the phone any more:
# - the files setup writes (setup_files: oFono's drop-in, the AppArmor profile, WirePlumber's drop-in, the D-Bus
#   policy), each only when it is there, by its fixed name;
# - linger turned off, only when setup's record says it was off before;
# - the packages setup's record lists (<home>/keeper/host/host_setup.json, counted only when root alone could have
#   written it, as setup's own check: record_trusted), only names of this script's own, and only those installed now,
#   removed with `apt-get remove` of exactly those: never a package that was there before setup (the record never
#   lists one), never another package apt would take with them (a look first, `apt-get -s`: when it would remove
#   anything else, every package stays), and nothing else apt offers to clean up. With no record (a line set up
#   before setup kept one), the packages and linger stay. The record goes once nothing it lists is left.
undo_setup() {
    need_root
    need_user
    [ -n "$SETUP_HOME" ] || die "undo-setup needs --home and the agents home on this computer."
    record="$(record_folder)/$SETUP_RECORD"
    trusted=""
    record_trusted "$record" && trusted=1

    part files
    if [ -f "$OFONO_DROPIN_DIR/phone-line.conf" ]; then
        act rm -f "$OFONO_DROPIN_DIR/phone-line.conf" || die "oFono's drop-in could not be removed."
        act rmdir "$OFONO_DROPIN_DIR" 2>/dev/null || true
        act systemctl daemon-reload || true
    fi
    if [ -f "$APPARMOR_DIR/$APPARMOR_PROFILE" ]; then
        if apparmor_on && apparmor_loaded; then
            act apparmor_parser -R "$APPARMOR_DIR/$APPARMOR_PROFILE" || true
        fi
        act rm -f "$APPARMOR_DIR/$APPARMOR_PROFILE" || die "The line's AppArmor profile could not be removed."
    fi
    wireplumber="$TARGET_HOME/.config/wireplumber/wireplumber.conf.d/51-phone-line.conf"
    if [ -f "$wireplumber" ]; then
        act as_user rm -f "$wireplumber" || die "WirePlumber's drop-in could not be removed."
    fi
    if [ -f /etc/dbus-1/system.d/ofono-phone-line.conf ]; then
        act rm -f /etc/dbus-1/system.d/ofono-phone-line.conf || die "The D-Bus policy could not be removed."
        act systemctl reload dbus || true
    fi
    part_done

    part linger
    if [ -n "$trusted" ] && grep -q '"linger_was_off": true' "$record" 2>/dev/null; then
        act loginctl disable-linger "$TARGET_USER" || die "linger could not be turned off."
        part_done
    else
        [ -z "${HELPER:-}" ] || say "STEP linger skipped"
        PART=""
    fi

    part packages
    listed=""
    if [ -n "$trusted" ]; then
        for package in $(record_packages "$record"); do
            package_present "$package" && listed="$listed $package"
        done
    else
        say "There is no record of what setup installed here: the packages stay."
    fi
    if [ -z "$listed" ]; then
        [ -z "${HELPER:-}" ] || say "STEP packages skipped"
        PART=""
    elif ! only_these_go "$listed"; then
        say "Other packages on this computer need some of$listed: every package stays."
        [ -z "${HELPER:-}" ] || say "STEP packages skipped"
        PART=""
        return 0
    else
        # shellcheck disable=SC2086
        DEBIAN_FRONTEND=noninteractive act apt-get remove -y $listed || die "The packages could not be removed."
        part_done
    fi
    if [ -n "$trusted" ]; then
        act rm -f "$record" || true
    fi
    say "Undone."
}

# Whether removing these packages takes nothing else with it: apt's own look (`apt-get -s remove`, which changes
# nothing) lists every package it would remove as `Remv <name>`.
only_these_go() {
    # shellcheck disable=SC2086
    plan=$(LC_ALL=C apt-get -s remove $1 2>/dev/null) || return 1
    for gone in $(printf '%s\n' "$plan" | sed -n 's/^Remv \([^ ]*\).*/\1/p'); do
        case " $1 " in *" $gone "*) ;; *) return 1 ;; esac
    done
}

# ---- test-call ---------------------------------------------------------------------------------------------------------

# The state of a call: dialing, alerting, active, disconnected... (oFono has no org.freedesktop.DBus.Properties).
call_state() {
    as_user busctl --system call org.ofono "$1" org.ofono.VoiceCall GetProperties 2>/dev/null | sed -n 's/.*"State" s "\([a-z]*\)".*/\1/p'
}

hang_up() {
    [ -n "${CALL:-}" ] && as_user busctl --system call org.ofono "$CALL" org.ofono.VoiceCall Hangup >/dev/null 2>&1
    CALL=""
}

# A node of PipeWire by name prefix (bluez_input / bluez_output), once the call's audio link is up.
audio_node() {
    as_user pw-cli ls Node 2>/dev/null | sed -n "s/.*node.name = \"\\($1[^\"]*\\)\".*/\\1/p" | head -n 1
}

# A tone: a square wave of 36 samples to the period (444 Hz at 16 kHz), 1.5 s, as raw 16-bit little-endian.
tone() {
    period='\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\100\037\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340\300\340'
    i=0
    while [ "$i" -lt 667 ]; do
        printf "$period"
        i=$((i + 1))
    done
}

test_call() {
    need_root
    need_user
    need_commands busctl pw-play pw-record pw-cli
    # Only an Israeli landline (9 digits) or mobile (10), as the line's own destination rule allows: no emergency,
    # short, premium-rate or international number. Israel's country code becomes a leading 0.
    number=$(printf '%s' "${1:-}" | tr -d ' ().-')
    case "$number" in
        +972*) number=${number#+972}; number="0${number#0}" ;;
    esac
    case "$number" in
        0[23489][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
        0[57][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
        *) die "Usage: sudo bash $0 test-call <your own Israeli number: a landline of 9 digits or a mobile of 10>" ;;
    esac
    modem=$(find_modem | head -n 1)
    [ -n "$modem" ] || die "oFono has no modem for the phone: run 'sudo bash $0 check' first."

    CALL=""
    trap hang_up EXIT
    trap 'exit 2' INT TERM HUP
    say "Dialing: your phone should ring. Answer it."
    CALL=$(as_user busctl --system call org.ofono "$modem" org.ofono.VoiceCallManager Dial ss "$number" "" 2>/dev/null | sed -n 's/^o "\(.*\)"$/\1/p')
    [ -n "$CALL" ] || die "The call could not be placed."
    waited=0
    state=""
    while [ "$waited" -lt "$CALL_RING_SECONDS" ]; do
        state=$(call_state "$CALL")
        [ "$state" = active ] && break
        [ "$state" = disconnected ] || [ -z "$state" ] && break
        sleep 1
        waited=$((waited + 1))
    done
    if [ "$state" != active ]; then
        say "The call was not answered (state: ${state:-gone}) within $CALL_RING_SECONDS seconds."
        exit 1
    fi
    say "Answered."

    waited=0
    out_node=""
    in_node=""
    while [ "$waited" -lt 10 ]; do
        out_node=$(audio_node bluez_output)
        in_node=$(audio_node 'bluez_input')
        [ -n "$out_node" ] && [ -n "$in_node" ] && break
        sleep 1
        waited=$((waited + 1))
    done
    [ -n "$in_node" ] || die "The call's audio did not appear in PipeWire (no bluez_input node)."

    # Nothing of the call is kept in a file: the tone is streamed in, and what is heard goes straight to the peak.
    say "Playing a tone into the call, and listening for $RECORD_SECONDS seconds. Say something."
    if [ -n "$out_node" ]; then
        tone | as_user pw-play --target "$out_node" --raw --rate 16000 --channels 1 --format s16 - 2>/dev/null
    else
        tone | as_user pw-play --raw --rate 16000 --channels 1 --format s16 - 2>/dev/null
    fi
    peak=$(as_user timeout "$RECORD_SECONDS" pw-record --target "$in_node" --raw --rate 16000 --channels 1 --format s16 - 2>/dev/null         | od -An -t d2 -v -w2 | awk 'function a(x) { return x < 0 ? -x : x } { if (a($1) > m) m = a($1) } END { print m + 0 }')
    hang_up
    say "Hung up."
    say "Heard: peak $peak of 32767 (0 is silence; a voice or a tone is in the thousands)."
    [ "${peak:-0}" -gt 0 ] || { say "Nothing was heard: check the phone's volume and that the call's audio went to this computer."; exit 1; }
}

# ---- the command -------------------------------------------------------------------------------------------------------

USAGE="Usage: sudo bash $0 setup | pair | check [the phone's address] | status | unpair <the phone's address> | test-call <your own number>"

# The command, then its one argument (check's address, test-call's number) and the options; anything else is refused.
# All of it is in this function, so with --helper (the script on standard input) it is read whole before it runs.
main() {
    COMMAND=${1:-}
    [ $# -gt 0 ] && shift
    HELPER=""
    HELPER_UID=""
    DRY_RUN=""
    ARG=""
    SETUP_HOME=""
    ANSWERS=""
    ADAPTER=""
    HERE="$(dirname "$(readlink -f "$0")")"
    files=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --helper) HELPER=1 ;;
            --dry-run) DRY_RUN=1 ;;
            --user) [ $# -ge 2 ] || die "$USAGE"; HELPER_UID=$2; shift ;;
            --files) [ $# -ge 2 ] || die "$USAGE"; files=$2; shift ;;
            --home) [ $# -ge 2 ] || die "$USAGE"; SETUP_HOME=$2; shift ;;
            --answers) [ $# -ge 2 ] || die "$USAGE"; ANSWERS=$2; shift ;;
            --adapter) [ $# -ge 2 ] || die "$USAGE"; ADAPTER=$2; shift ;;
            -*) die "$USAGE" ;;
            *) [ -z "$ARG" ] || die "$USAGE"; ARG=$1 ;;
        esac
        shift
    done
    if [ -n "$HELPER" ]; then
        case "$HELPER_UID" in
            ''|0|*[!0-9]*) die "--helper needs --user and the line's user id." ;;
        esac
        case "$files" in
            /*) HERE=$files ;;
            *) die "--helper needs --files and the folder of this script's files." ;;
        esac
        exec </dev/null          # the script itself came on standard input: nothing it runs reads the rest
    elif [ -n "$HELPER_UID" ] || [ -n "$files" ] || [ -n "$SETUP_HOME" ] || [ -n "$ANSWERS" ]; then
        die "--user, --files, --home and --answers go only with --helper."
    fi
    # Each folder is a plain absolute path (no "..", nothing a shell could read as more), each only where it is taken.
    for folder in "$SETUP_HOME" "$ANSWERS"; do
        case "$folder" in
            '') ;;
            *[!A-Za-z0-9._/-]*|*/../*|*/..|*//*) die "$USAGE" ;;
            /*) ;;
            *) die "$USAGE" ;;
        esac
    done
    case "$COMMAND" in
        setup|line-up|undo-setup) ;;
        *) [ -z "$SETUP_HOME" ] || die "--home is for setup, line-up and undo-setup." ;;
    esac
    [ -z "$ANSWERS" ] || [ "$COMMAND" = pair ] || die "--answers is for pair."
    case "$ADAPTER" in
        ''|hci[0-9]|hci[0-9][0-9]) ;;
        *) die "$USAGE" ;;
    esac
    [ -z "$ADAPTER" ] || [ "$COMMAND" = pair ] || [ "$COMMAND" = unpair ] || die "--adapter is for pair and unpair."
    APPARMOR_SOURCE="$HERE/phone-line.apparmor"
    if [ -n "$DRY_RUN" ]; then
        case "$COMMAND" in
            setup|status|pair|line-up|line-down|unpair|undo-setup) ;;
            *) die "--dry-run is for setup, status, pair, line-up, line-down, unpair and undo-setup." ;;
        esac
    fi
    case "$COMMAND" in
        setup) setup ;;
        pair) pair ;;
        check) check "$ARG" ;;
        status) status ;;
        test-call) test_call "$ARG" ;;
        line-up) [ -n "$HELPER" ] || die "$USAGE"; line_up ;;
        line-down) [ -n "$HELPER" ] || die "$USAGE"; line_down ;;
        unpair) unpair "$ARG" ;;
        undo-setup) [ -n "$HELPER" ] || die "$USAGE"; undo_setup ;;
        *) die "$USAGE" ;;
    esac
}

main "$@"
