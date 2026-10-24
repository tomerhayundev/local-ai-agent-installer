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
#
# The installer runs it by itself (A phone agent, or A phone line, on Linux): `status` first, then only what is missing,
# with `--installer` after setup and pair, which leaves out the hints for running it by hand. It makes a test call only
# when the computer's owner types yes and then a number. Run by hand, choose "A phone line" in the installer
# afterwards. Setup, check and the test call were
# proven on a real Ubuntu server (oFono as the hands-free backend, PipeWire for the audio); pairing is phone-line-pair.py,
# which sits next to this file, and so does phone-line.apparmor, the line container's AppArmor profile (setup installs
# it on a computer with AppArmor). Nothing in it is personal: the phone's
# address and the numbers are what you type or what the pairing prints, and they stay on this computer.
set -u

PACKAGES="bluez ofono pipewire pipewire-bin wireplumber libspa-0.2-bluetooth"
PAIR_PACKAGES="python3-dbus python3-gi"      # for phone-line-pair.py, the pairing agent
PAIR_SECONDS=180
CALL_RING_SECONDS=45
RECORD_SECONDS=5

say() { printf '%s\n' "$*"; }
# A hint for running it by hand, left out when the installer runs it (`--installer`, the argument after the command).
hint() { [ "${FROM_INSTALLER:-}" = 1 ] || say "$*"; }
die() { printf '%s\n' "$*" >&2; exit 2; }

need_root() {
    [ "$(id -u)" = 0 ] || die "Run it with sudo: sudo bash $0 $COMMAND"
}

# The user the line runs as: the one who typed sudo. Its PipeWire, its D-Bus policy, its linger.
need_user() {
    TARGET_USER=${SUDO_USER:-}
    [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != root ] || die "Run it with sudo from your own user (not from root's own shell): the phone line runs as that user."
    TARGET_UID=$(id -u "$TARGET_USER") || die "There is no user $TARGET_USER."
    TARGET_GROUP=$(id -gn "$TARGET_USER")
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    [ -n "$TARGET_HOME" ] && [ -d "$TARGET_HOME" ] || die "The home folder of $TARGET_USER could not be found."
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
# is loaded; the installer passes that on to the line's compose, which then names the profile. A computer without
# AppArmor (or without apparmor_parser, which Docker needs as well to confine anything) gets no profile: Docker applies
# none there.
APPARMOR_PROFILE=local-ai-agent-phone-line
APPARMOR_SOURCE="$(dirname "$(readlink -f "$0")")/phone-line.apparmor"
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

setup() {
    need_root
    need_user
    command -v apt-get >/dev/null 2>&1 || die "setup uses apt (Ubuntu or Debian). Install these yourself: $PACKAGES"
    say "Installing: $PACKAGES $PAIR_PACKAGES"
    apt-get update -qq || die "apt could not update its lists."
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $PACKAGES $PAIR_PACKAGES || die "The packages could not be installed."
    rfkill unblock bluetooth 2>/dev/null || true
    say "oFono: it starts again by itself when it stops on an error."
    ofono_restarts "$OFONO_DROPIN_DIR" || die "The oFono setting could not be written."
    systemctl enable --now bluetooth ofono || die "bluetooth and ofono could not be started."
    if apparmor_on; then
        say "AppArmor: the phone line's container gets its own profile ($APPARMOR_PROFILE)."
        apparmor_install || die "The phone line's AppArmor profile could not be installed and loaded (above is why)."
    fi

    say "Turning on linger for $TARGET_USER, so PipeWire runs without a login."
    loginctl enable-linger "$TARGET_USER" || die "linger could not be turned on."
    systemctl start "user@$TARGET_UID.service" 2>/dev/null || true
    waited=0
    while [ ! -d "/run/user/$TARGET_UID" ] && [ "$waited" -lt 30 ]; do
        sleep 1
        waited=$((waited + 1))
    done
    [ -d "/run/user/$TARGET_UID" ] || die "/run/user/$TARGET_UID did not appear: the user's systemd is not running."
    as_user systemctl --user enable --now pipewire.socket pipewire.service wireplumber.service || die "PipeWire and WirePlumber could not be started for $TARGET_USER."

    say "WirePlumber: oFono carries the hands-free profile, and this computer is only a hands-free unit."
    dropin="$TARGET_HOME/.config/wireplumber/wireplumber.conf.d"
    as_user mkdir -p "$dropin" || die "$dropin could not be made."
    as_user tee "$dropin/51-phone-line.conf" >/dev/null <<'EOF'
monitor.bluez.properties = {
  bluez5.hfphsp-backend = "ofono"
  bluez5.roles = [ hfp_hf ]
}
EOF
    [ $? = 0 ] || die "The WirePlumber settings could not be written."

    say "D-Bus: $TARGET_USER may talk to oFono."
    cat > /etc/dbus-1/system.d/ofono-phone-line.conf <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="$TARGET_USER">
    <allow send_destination="org.ofono"/>
  </policy>
</busconfig>
EOF
    [ $? = 0 ] || die "The D-Bus policy could not be written."
    systemctl reload dbus || die "D-Bus could not reload its policy."
    as_user systemctl --user restart wireplumber || die "WirePlumber could not restart."

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
pair() {
    need_root
    need_user
    need_commands python3 timeout
    systemctl is-active --quiet bluetooth || die "Bluetooth is not running: run 'sudo bash $0 setup' first."
    python3 -I -c 'import dbus, gi' 2>/dev/null || die "python3-dbus and python3-gi are missing: run 'sudo bash $0 setup' first."
    agent="$(dirname "$(readlink -f "$0")")/phone-line-pair.py"
    [ -f "$agent" ] || die "phone-line-pair.py is missing: it belongs next to phone-line.sh."
    # The agent keeps to its own window; this is only the last word if it hangs (TERM first, then KILL).
    timeout --foreground -k 10 $((PAIR_SECONDS + 30)) python3 -I "$agent" "$PAIR_SECONDS"
    code=$?
    # Whatever happened to the agent, the adapter does not stay open for pairing.
    timeout --foreground 5 bluetoothctl discoverable off >/dev/null 2>&1
    timeout --foreground 5 bluetoothctl pairable off >/dev/null 2>&1
    [ "$code" = 0 ] || exit "$code"
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

# With an address (the installer gives the phone's), only that phone's modem counts, and only it is asked to connect:
# another phone in reach is never taken for it. Without one, the first modem, and every paired device is asked.
check() {
    need_root
    need_user
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
        exit 1
    fi
    address=$(modem_address "$modem")
    name=$(device_name "$address")
    say "ok $address ${name:-}"
}

# ---- status ------------------------------------------------------------------------------------------------------------

# What is done on this computer already, one fact a line, for the installer (it does only what is missing). It changes
# nothing:
#   setup ready | setup needed   all that `setup` does: the packages, Bluetooth and oFono running, linger, the user's
#                                PipeWire socket, the WirePlumber settings, the D-Bus policy for the user and oFono's
#                                drop-in that starts it again (a computer set up before it gets it on the next run),
#                                and on a computer with AppArmor the line's profile, installed and loaded
#   paired <address>             each device BlueZ has paired
#   modem <address>              each phone oFono has a hands-free modem for (paired, and in reach now)
#   apparmor <profile>           the line's AppArmor profile is loaded (only on a computer with AppArmor; there,
#                                setup ready includes it, as this script ships it)
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

COMMAND=${1:-}
FROM_INSTALLER=""
[ "${2:-}" = --installer ] && FROM_INSTALLER=1
case "$COMMAND" in
    setup) setup ;;
    pair) pair ;;
    check) check "${2:-}" ;;
    status) status ;;
    test-call) shift; test_call "${1:-}" ;;
    *) die "Usage: sudo bash $0 setup | pair | check | status | test-call <your own number>" ;;
esac
