#!/bin/sh
# Installs a personal AI agent on this computer (macOS or Linux): Docker if it is missing, then the agent's package,
# its keeper and the agent itself. Run it as yourself, with `sh install-agent.sh` (on a Mac, double-click
# install-agent.command); it asks for sudo when it needs it.
#
# The questions and the work are in the package: each step is `python install.py <step>` in one `docker run`. This
# script only does what can't happen inside a container: it installs and starts Docker, gathers this computer's facts,
# pulls the image, runs the steps one after another, starts what they ask for and opens their links (the front-end
# contract in the installers plan).
set -u

PACKAGE="${LOCAL_AI_AGENT_PACKAGE:-ghcr.io/tomerhayundev/local-ai-agent}"
NETWORK=local-ai-agent-net
LICENSE_URL=https://www.docker.com/legal/docker-subscription-service-agreement/
ENGINE_URL=https://docs.docker.com/engine/install/
DOCKER_WAIT=300
COMPOSE_MAJOR=2
COMPOSE_MINOR=30
VERSION_LABEL=org.opencontainers.image.version

say() {
    printf '%s\n' "$*"
}

# Stops before the installer changed anything itself (or after something outside the steps failed).
stop() {
    say "$*"
    say "The installer stopped."
    wait_for_enter
    exit 2
}

# A step ended with exit 1 or 2: it has said why.
step_stopped() {
    say "The installer stopped. Nothing else was changed."
    wait_for_enter
    exit 2
}

wait_for_enter() {
    say "Press Enter to close."
    read -r _ || true
}

as_root() {
    if [ "$(id -u)" = 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# ---- Before anything: who, where and what -------------------------------------------------------------------------

check_user() {
    if [ -n "${SUDO_USER:-}" ]; then
        say "run it without sudo; it asks for sudo when it needs it"
        exit 2
    fi
    USER_NAME=$(id -un)
}

check_package() {
    case "$PACKAGE" in
        *@*|"") stop "This installer has no package filled in. Set LOCAL_AI_AGENT_PACKAGE to the package's address." ;;
    esac
}

find_system() {
    case "$(uname -s)" in
        Darwin)
            OS=macos
            AGENTS_HOME="$HOME/Library/Application Support/LocalAIAgent"
            PATH="$PATH:/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin"
            export PATH
            ;;
        Linux)
            OS=linux
            AGENTS_HOME="$HOME/.local/share/local-ai-agent"
            if [ ! -c /dev/net/tun ]; then
                stop "this machine has no /dev/net/tun; ask your provider to turn on TUN"
            fi
            ;;
        *)
            stop "This installer is for macOS and Linux. On Windows, double-click install-agent.cmd."
            ;;
    esac
}

docker_missing() {
    if [ "$OS" = macos ]; then
        ! command -v docker >/dev/null 2>&1 && [ ! -d /Applications/Docker.app ]
    else
        ! command -v docker >/dev/null 2>&1
    fi
}

confirm() {
    if [ -n "${LOCAL_AI_AGENT_CONFIRMED:-}" ]; then
        return 0
    fi
    say "This installer will:"
    if docker_missing; then
        if [ "$OS" = macos ]; then
            say "  - Install Docker Desktop and accept Docker's license (free for personal use, and for small"
            say "    businesses under Docker's terms): $LICENSE_URL"
        else
            say "  - Install Docker Engine and its Compose plugin from Docker's own repository, and add you to the"
            say "    docker group (Docker Engine is free; Docker Desktop's license, free for personal use, is at"
            say "    $LICENSE_URL)"
        fi
    fi
    say "  - Download the agent's package ($PACKAGE)"
    say "  - Create the agents home: $AGENTS_HOME"
    say "  - Start the keeper and the agent"
    say "  - Open a Tailscale sign-in in your browser (unless you choose home Wi-Fi only)"
    say "Type yes to go on:"
    answer=""
    read -r answer || true
    case "$answer" in
        [Yy]|[Yy][Ee][Ss]) LOCAL_AI_AGENT_CONFIRMED=1; export LOCAL_AI_AGENT_CONFIRMED ;;
        *) say "Nothing was changed."; exit 2 ;;
    esac
}

# ---- Docker ---------------------------------------------------------------------------------------------------------

# Whether the app at $1 is intact, accepted by Gatekeeper, and signed with Docker Inc's Developer ID. As root, since
# it sits in a folder only root can read.
docker_app_verified() {
    as_root codesign --verify --deep --strict "$1" >/dev/null 2>&1 || return 1
    as_root spctl -a -t exec "$1" >/dev/null 2>&1 || return 1
    as_root codesign -dv --verbose=2 "$1" 2>&1 | grep -q '^Authority=Developer ID Application: Docker Inc'
}

# Leaves no disk image mounted and no download behind.
drop_disk_image() {
    as_root hdiutil detach "$1/mount" >/dev/null 2>&1
    as_root rm -rf "$1"
}

install_docker_macos() {
    if command -v brew >/dev/null 2>&1; then
        # The cask's download is verified by Homebrew itself (its SHA-256 in the cask) and Gatekeeper checks the app.
        say "Installing Docker Desktop with Homebrew..."
        brew install --cask docker-desktop || stop "Homebrew could not install Docker Desktop."
        return 0
    fi
    case "$(uname -m)" in
        arm64) arch=arm64 ;;
        x86_64) arch=amd64 ;;
        *) stop "Docker Desktop has no disk image for this Mac ($(uname -m))." ;;
    esac
    # Docker's own installer runs as root, so everything it comes from stays where only root can write: a fresh
    # folder of root's (mktemp makes it 700), the download, the read-only mount and the signature check.
    say "Downloading Docker Desktop (sudo asks for your password)..."
    folder=$(as_root mktemp -d /tmp/install-agent.XXXXXX) || stop "No room for Docker's disk image."
    as_root curl -fL --progress-bar -o "$folder/Docker.dmg" "https://desktop.docker.com/mac/main/$arch/Docker.dmg" \
        || { drop_disk_image "$folder"; stop "Docker Desktop could not be downloaded."; }
    as_root mkdir "$folder/mount"
    as_root hdiutil attach -nobrowse -readonly -mountpoint "$folder/mount" "$folder/Docker.dmg" >/dev/null \
        || { drop_disk_image "$folder"; stop "Docker's disk image could not be opened."; }
    if ! docker_app_verified "$folder/mount/Docker.app"; then
        drop_disk_image "$folder"
        stop "The Docker Desktop download could not be verified; nothing was installed."
    fi
    say "Installing Docker Desktop..."
    if ! as_root "$folder/mount/Docker.app/Contents/MacOS/install" --accept-license --user="$USER_NAME"; then
        drop_disk_image "$folder"
        stop "Docker Desktop could not be installed."
    fi
    drop_disk_image "$folder"
}

install_docker_linux() {
    if [ ! -r /etc/os-release ]; then
        stop "Install Docker Engine and its Compose plugin from $ENGINE_URL, then run this installer again."
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
        *" ubuntu "*) distro=ubuntu ;;
        *" debian "*) distro=debian ;;
        *) stop "This installer sets Docker up on Debian and Ubuntu only. Install Docker Engine and its Compose" \
                "plugin from $ENGINE_URL, then run this installer again." ;;
    esac
    if [ "${ID:-}" = ubuntu ] || [ "${ID:-}" = debian ]; then
        distro=$ID
    fi
    codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    if [ -z "$codename" ]; then
        stop "This system doesn't say which release it is. Install Docker Engine from $ENGINE_URL."
    fi
    say "Installing Docker Engine from Docker's repository (sudo asks for your password)..."
    as_root apt-get update || stop "apt-get update failed."
    as_root apt-get install -y ca-certificates curl || stop "curl could not be installed."
    as_root install -m 0755 -d /etc/apt/keyrings || stop "/etc/apt/keyrings could not be made."
    as_root curl -fsSL "https://download.docker.com/linux/$distro/gpg" -o /etc/apt/keyrings/docker.asc \
        || stop "Docker's signing key could not be downloaded."
    as_root chmod a+r /etc/apt/keyrings/docker.asc
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
        "$(dpkg --print-architecture)" "$distro" "$codename" \
        | as_root tee /etc/apt/sources.list.d/docker.list >/dev/null || stop "Docker's repository could not be added."
    # A derivative with a codename of its own (Pop!_OS, Devuan) gets a line Docker's repository has no packages for.
    as_root apt-get update || stop "apt-get update failed after adding Docker's repository to" \
        "/etc/apt/sources.list.d/docker.list (https://download.docker.com/linux/$distro, release $codename): Docker" \
        "may have no packages for this system's release. Remove that file, install Docker Engine from $ENGINE_URL," \
        "then run this installer again."
    as_root apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        || stop "Docker Engine could not be installed."
}

in_docker_group_now() {
    id -nG | tr ' ' '\n' | grep -qx docker
}

listed_in_docker_group() {
    getent group docker | cut -d: -f4 | tr ',' '\n' | grep -qx "$USER_NAME"
}

# Linux: the daemon running, and this user able to reach it (the docker group, taken up at once through sg).
start_docker_linux() {
    if docker info >/dev/null 2>&1; then
        return 0
    fi
    if command -v systemctl >/dev/null 2>&1 && ! systemctl is-active --quiet docker; then
        as_root systemctl enable --now docker || stop "Docker could not be started (systemctl enable --now docker)."
    fi
    if [ "$(id -u)" = 0 ] || in_docker_group_now; then
        return 0
    fi
    if ! listed_in_docker_group; then
        as_root usermod -aG docker "$USER_NAME" || stop "You could not be added to the docker group."
    fi
    if [ -n "${LOCAL_AI_AGENT_IN_SG:-}" ]; then
        stop "The docker group didn't take effect. Sign out and in again, then run this installer again."
    fi
    LOCAL_AI_AGENT_IN_SG=1
    LOCAL_AI_AGENT_SCRIPT="$SCRIPT"
    export LOCAL_AI_AGENT_IN_SG LOCAL_AI_AGENT_SCRIPT
    # shellcheck disable=SC2016
    exec sg docker -c 'exec /bin/sh "$LOCAL_AI_AGENT_SCRIPT"'
}

wait_for_docker() {
    if docker info >/dev/null 2>&1; then
        return 0
    fi
    say "Waiting for Docker to start (up to 5 minutes)..."
    waited=0
    while [ "$waited" -lt "$DOCKER_WAIT" ]; do
        sleep 3
        waited=$((waited + 3))
        if docker info >/dev/null 2>&1; then
            return 0
        fi
    done
    stop "Docker didn't start within 5 minutes. Start Docker, then run this installer again."
}

check_compose() {
    version=$(docker compose version --short 2>/dev/null)
    version=${version#v}
    major=${version%%.*}
    rest=${version#*.}
    minor=${rest%%.*}
    case "$major$minor" in
        ""|*[!0-9]*) major=0; minor=0 ;;
    esac
    if [ "$major" -gt "$COMPOSE_MAJOR" ] || { [ "$major" -eq "$COMPOSE_MAJOR" ] && [ "$minor" -ge "$COMPOSE_MINOR" ]; }
    then
        return 0
    fi
    stop "Docker Compose 2.30 or newer is needed (this computer has ${version:-none}). Update Docker, then run this" \
         "installer again."
}

prepare_docker() {
    if docker_missing; then
        if [ "$OS" = macos ]; then
            install_docker_macos
        else
            install_docker_linux
        fi
    fi
    if [ "$OS" = macos ]; then
        if ! docker info >/dev/null 2>&1; then
            open -a Docker || stop "Docker Desktop could not be started."
        fi
    else
        start_docker_linux
    fi
    wait_for_docker
    check_compose
}

# ---- This computer's facts (the thirteen names of the front-end contract) ------------------------------------------

# This computer's own DNS servers, separated by spaces, for a Tailscale agent's sidecar to ask after the tailnet's
# resolver: resolvectl's Current DNS Server, else the nameserver lines of systemd-resolved's real list or of
# /etc/resolv.conf, never a 127.x stub. The step keeps only IPv4 addresses that a container can ask (installer.facts).
host_dns() {
    servers=""
    if command -v resolvectl >/dev/null 2>&1; then
        servers=$(resolvectl status 2>/dev/null | awk '/Current DNS Server:/ { print $NF }')
    fi
    if [ -z "$servers" ]; then
        for file in /run/systemd/resolve/resolv.conf /etc/resolv.conf; do
            if [ -r "$file" ]; then
                servers=$(awk '$1 == "nameserver" && $2 !~ /^127\./ { print $2 }' "$file")
            fi
            if [ -n "$servers" ]; then
                break
            fi
        done
    fi
    printf '%s\n' "$servers" | awk 'NF && !seen[$1]++ { print $1 }' | head -n 6 | tr '\n' ' '
}

gather_facts() {
    HOST_HOME="$AGENTS_HOME"
    HOST_PLATFORM="$OS"
    HOST_UID=""
    HOST_GID=""
    DOCKER_GID=""
    KEEPER_USER=""
    AGENT_USER=""
    if [ "$OS" = macos ]; then
        HOST_NAME=$(scutil --get LocalHostName 2>/dev/null || hostname)
        zone=$(readlink /etc/localtime 2>/dev/null)
        HOST_TZ=${zone#*zoneinfo/}
        language=$(defaults read -g AppleLanguages 2>/dev/null | sed -n 2p | tr -d ' ",')
        HOST_LANG=${language%%-*}
        interface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2; exit }')
        HOST_LAN=""
        if [ -n "$interface" ]; then
            HOST_LAN=$(ipconfig getifaddr "$interface" 2>/dev/null)
        fi
        # Not on Docker Desktop: its own DNS stands between the containers and this computer, and a router's address
        # may not answer from there. The installer says what that leaves out.
        HOST_DNS=""
    else
        HOST_NAME=$(hostname)
        HOST_TZ=$(timedatectl show -p Timezone --value 2>/dev/null)
        if [ -z "$HOST_TZ" ]; then
            zone=$(readlink /etc/localtime 2>/dev/null)
            HOST_TZ=${zone#*zoneinfo/}
        fi
        HOST_LANG=${LANG:-}
        HOST_LANG=${HOST_LANG%%_*}
        HOST_LAN=$(ip -4 route get 1.1.1.1 2>/dev/null |
            awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }')
        HOST_DNS=$(host_dns)
        # Ruling 16: on Linux every step, the keeper and the agent run as this user, with the socket's group.
        HOST_UID=$(id -u)
        HOST_GID=$(id -g "$USER_NAME")
        DOCKER_GID=$(stat -c %g /var/run/docker.sock)
        KEEPER_USER="$HOST_UID:$HOST_GID"
        AGENT_USER="$KEEPER_USER"
    fi
    export HOST_HOME HOST_PLATFORM HOST_NAME HOST_TZ HOST_LANG HOST_LAN HOST_UID HOST_GID DOCKER_GID PACKAGE \
        KEEPER_USER AGENT_USER HOST_DNS
}

# ---- The package ----------------------------------------------------------------------------------------------------

# Gives what the front end made the user's own group. After the `sg docker` re-run this process's group is docker,
# and the agents home has one owner, uid and gid (Ruling 16). Usage: own_group [-R] <path>...
own_group() {
    if [ "$OS" != linux ] || [ "$(id -g)" = "$HOST_GID" ]; then
        return 0
    fi
    if [ "$1" = -R ]; then
        shift
        chgrp -R "$HOST_GID" "$@"
    else
        chgrp "$HOST_GID" "$@"
    fi
}

# mkdir -p, with every folder it makes in the user's own group.
make_folder() {
    if [ -d "$1" ]; then
        return 0
    fi
    first=$1
    while [ ! -e "$(dirname "$first")" ]; do
        first=$(dirname "$first")
    done
    mkdir -p "$1" || return 1
    own_group -R "$first"
}

make_home() {
    make_folder "$AGENTS_HOME" || stop "The agents home could not be made: $AGENTS_HOME"
}

pull_image() {
    say "Downloading the agent's package..."
    docker pull "$PACKAGE:latest" || stop "The package could not be downloaded: $PACKAGE:latest"
    version=$(docker image inspect --format "{{ index .Config.Labels \"$VERSION_LABEL\" }}" "$PACKAGE:latest" \
        2>/dev/null)
    case "$version" in
        ""|"<no value>") stop "this package has no version" ;;
        *[!A-Za-z0-9._-]*) stop "this package's version is not a plain version" ;;
    esac
    IMAGE="$PACKAGE:$version"
    docker pull "$IMAGE" >/dev/null || stop "The package could not be downloaded: $IMAGE"
}

one_installer() {
    state=$(docker container inspect --format '{{.State.Running}}' agent-installer 2>/dev/null)
    case "$state" in
        true) stop "Another installer is running on this computer. Let it finish, then run this one again." ;;
        false) docker rm -f agent-installer >/dev/null 2>&1 ;;
    esac
}

# ---- The phone line's host part (HOST phone-line, Linux) ------------------------------------------------------------
# A step asks for it with a `HOST phone-line` line (a new phone agent, or the menu's phone line). It is what a container
# can't do on this computer: the packages, Bluetooth, oFono and PipeWire, and pairing the phone. phone-line.sh does it
# (it sits next to this script, with phone-line-pair.py), with sudo. It asks phone-line.sh first what is done already
# and does only what is missing, so a second phone agent, or a run again, sets nothing up and pairs nothing twice. The
# phone's address goes to <home>/phone-line/paired_phone, for the step that follows, and the line's AppArmor profile, when
# this computer has it loaded, to <home>/phone-line/apparmor_profile. A test call is made only when the computer's
# owner types yes and then a number, and is offered only when this run set something up or paired the phone.

PHONE_PAIRED=phone-line/paired_phone
PHONE_APPARMOR=phone-line/apparmor_profile
LINE_PROFILE=local-ai-agent-phone-line
ADDRESS_RE='[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]'

# phone-line.sh's `status` (setup ready/needed, paired <address>, modem <address>), kept in $WORK/phone-status.
phone_status() {
    as_root bash "$LINE_SCRIPT" status > "$WORK/phone-status" \
        || stop "phone-line.sh couldn't look at this computer (above is why). Fix that, then run the installer again."
}

phone_has() {
    grep -qx "$1" "$WORK/phone-status"
}

# Addresses read from stdin, in capitals, one a line; anything that is not an address is dropped.
phone_addresses() {
    tr 'abcdef' 'ABCDEF' | grep -x "$ADDRESS_RE"
}

# The addresses of one kind of `status` line (paired, modem).
phone_list() {
    sed -n "s/^$1 //p" "$WORK/phone-status" | phone_addresses
}

phone_count() {
    if [ -z "$1" ]; then
        echo 0
    else
        printf '%s\n' "$1" | grep -c .
    fi
}

# The phone's address, for the step that follows: written as soon as it is known.
phone_save() {
    make_folder "$AGENTS_HOME/phone-line" || stop "The phone line's folder could not be made in $AGENTS_HOME."
    printf '%s\n' "$1" > "$AGENTS_HOME/$PHONE_PAIRED" || stop "The phone's address could not be saved."
    own_group "$AGENTS_HOME/$PHONE_PAIRED"
}

# The line's AppArmor profile, for the step that writes the line's compose: its name when phone-line.sh's status says
# it is loaded here (a computer with AppArmor, set up), and no file otherwise (no AppArmor: Docker applies no profile,
# and the compose names none). Written again on every run, so a computer that changed is followed.
phone_apparmor() {
    make_folder "$AGENTS_HOME/phone-line" || stop "The phone line's folder could not be made in $AGENTS_HOME."
    if phone_has "apparmor $LINE_PROFILE"; then
        printf '%s\n' "$LINE_PROFILE" > "$AGENTS_HOME/$PHONE_APPARMOR" \
            || stop "The phone line's AppArmor setting could not be saved."
        own_group "$AGENTS_HOME/$PHONE_APPARMOR"
    else
        rm -f "$AGENTS_HOME/$PHONE_APPARMOR" || stop "The phone line's old AppArmor setting could not be removed."
    fi
}

# Prints the number as the line would call it (+972 made a leading 0), or nothing: only an Israeli landline (0 and
# 2, 3, 4, 8 or 9, then 7 digits) or mobile (05 or 07, then 8 digits), as the line's own destination rule allows. So no
# emergency, short, premium-rate or international number. Spaces, dashes, dots and brackets are left out first.
phone_number() {
    raw=$(printf '%s' "$1" | tr -d ' ().-')
    case "$raw" in
        +972*) raw=${raw#+972}; raw="0${raw#0}" ;;
        +*) return 0 ;;
    esac
    case "$raw" in
        0[23489][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) printf '%s\n' "$raw" ;;
        0[57][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) printf '%s\n' "$raw" ;;
    esac
}

# Never by default: only a typed yes, then a number typed at that moment. Nothing of it is kept.
phone_test_call() {
    say ""
    say "Try the line with a test call to your own phone? It has no AI: it rings you, plays a tone and listens"
    say "for 5 seconds. Type yes for it; Enter skips it."
    answer=""
    read -r answer || true
    case "$answer" in
        [Yy]|[Yy][Ee][Ss]) ;;
        *) say "No test call."; return 0 ;;
    esac
    while :; do
        say "Your own phone number (not the line's phone), or Enter for no call:"
        typed=""
        if ! read -r typed && [ -z "$typed" ]; then
            say "No test call."
            return 0
        fi
        if [ -z "$typed" ]; then
            say "No test call."
            return 0
        fi
        number=$(phone_number "$typed")
        if [ -n "$number" ]; then
            break
        fi
        say "Only an Israeli number can be called: a landline of 9 digits or a mobile of 10 (no emergency, short,"
        say "premium-rate or international numbers). Type it again."
    done
    as_root bash "$LINE_SCRIPT" test-call "$number" \
        || say "The test call didn't pass (above is why). The installer goes on; the line's state comes at the end."
}

phone_host() {
    if [ "$OS" != linux ]; then
        stop "The phone line works only on Linux for now."
    fi
    LINE_SCRIPT="$SCRIPT_DIR/phone-line.sh"
    if [ ! -f "$LINE_SCRIPT" ] || [ ! -f "$SCRIPT_DIR/phone-line-pair.py" ]; then
        stop "phone-line.sh and phone-line-pair.py belong next to install-agent.sh (they come in install-linux.zip)." \
             "Put them back, then run the installer again."
    fi
    say ""
    say "The phone line's part on this computer: Bluetooth, oFono, PipeWire, and pairing the phone."
    say "It runs phone-line.sh with sudo (sudo may ask for your password)."
    phone_status
    fresh=""
    if phone_has "setup ready"; then
        say "This computer is set up for the phone line already."
    else
        as_root bash "$LINE_SCRIPT" setup --installer \
            || stop "The phone line's setup didn't finish (above is why). Run the installer again once that is fixed."
        phone_status
        phone_has "setup ready" \
            || stop "The setup ran, but this computer still isn't ready for the phone line (above is what failed)." \
                    "Run the installer again once that is fixed."
        fresh=1
    fi
    phone_apparmor
    # The phone this installer saved before, or the one a line set up earlier (by hand, say) has in its line.env.
    known=$(head -n 1 "$AGENTS_HOME/$PHONE_PAIRED" 2>/dev/null | phone_addresses)
    if [ -z "$known" ]; then
        known=$(sed -n 's/^PHONE_ADDRESS=//p' "$AGENTS_HOME/phone-line/line.env" 2>/dev/null | tail -n 1 \
            | phone_addresses)
    fi
    paired=$(phone_list paired)
    modems=$(phone_list modem)
    address=""
    if [ -n "$known" ] && printf '%s\n' "$paired" | grep -qx "$known"; then
        address=$known
        say "The phone $address is paired already."
    elif [ -z "$known" ] && [ "$(phone_count "$modems")" = 1 ]; then
        address=$modems
        say "A phone is paired and connected already: $address"
    elif [ -z "$known" ] && [ -z "$modems" ] && [ "$(phone_count "$paired")" = 1 ]; then
        address=$paired
        say "A phone is paired already: $address"
    fi
    if [ -z "$address" ]; then
        say ""
        say "Now pair the phone: keep it next to this computer, with its Bluetooth on."
        say "The phone and this screen show the same 6-digit code: check it, then type yes here."
        as_root bash "$LINE_SCRIPT" pair --installer \
            || stop "No phone was paired. Run the installer again to try once more."
        fresh=1
        # The phone is the one device paired now that wasn't before. It is saved at once, so a run again that can't
        # reach it yet does not pair it a second time.
        phone_status
        if [ -n "$paired" ]; then
            printf '%s\n' "$paired" > "$WORK/paired-before"
            new=$(phone_list paired | grep -vxF -f "$WORK/paired-before")
        else
            new=$(phone_list paired)
        fi
        if [ "$(phone_count "$new")" != 1 ]; then
            stop "The phone paired, but this computer can't tell which device it is. Remove the phones you don't" \
                 "want in Bluetooth's settings (bluetoothctl remove <address>), then run the installer again."
        fi
        address=$new
        phone_save "$address"
    fi
    say "Checking that this computer reaches the phone (up to 30 seconds)..."
    checked=$(as_root bash "$LINE_SCRIPT" check "$address" 2>/dev/null | sed -n 's/^ok \([^ ]*\).*/\1/p' \
        | phone_addresses | head -n 1)
    if [ "$checked" = "$address" ]; then
        say "This computer reaches the phone ($address)."
    else
        checked=""
        say "The phone $address isn't in reach right now (is it near, with Bluetooth on?)."
        say "The line reaches it when it is."
    fi
    phone_save "$address"
    if [ -n "$fresh" ] && [ -n "$checked" ]; then
        phone_test_call
    fi
}

# ---- The steps ------------------------------------------------------------------------------------------------------

open_link() {
    # Only a web link, in one piece: `open` and xdg-open would also start a program or open a file.
    case "$1" in
        http://*|https://*) ;;
        *) return 0 ;;
    esac
    case "$1" in
        *[[:space:]]*|*[[:cntrl:]]*) return 0 ;;
    esac
    if [ "$OS" = macos ]; then
        open "$1" >/dev/null 2>&1
    elif [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$1" >/dev/null 2>&1 &
    else
        say "(There's no browser on this computer: open that link yourself.)"
    fi
}

# Shows the step's lines as they come, opens OPEN links at once, and keeps UP, NEXT, HOST and PROBE for after the step.
read_lines() {
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            "OPEN "*) open_link "${line#OPEN }" ;;
            "UP "*|"NEXT "*|"HOST "*|"PROBE "*) printf '%s\n' "$line" >> "$1" ;;
            # A secret is asked next (a key): what is typed is not shown until SHOW.
            HIDE) stty -echo < /dev/tty 2>/dev/null ;;
            SHOW) stty echo < /dev/tty 2>/dev/null ;;
            *) printf '%s\n' "$line" ;;
        esac
    done
}

# One step: `run_step <user> <step> [args]`. Sets STEP_CODE and leaves the step's UP, NEXT and PROBE lines in
# $ACTIONS.
run_step() {
    user=$1
    shift
    network_args=""
    if docker network inspect "$NETWORK" >/dev/null 2>&1; then
        network_args="--network $NETWORK"
    fi
    group_args=""
    pipewire_args=""
    if [ "$OS" = linux ]; then
        group_args="--group-add $DOCKER_GID"
        # The phone line step checks that this user's PipeWire runs: its socket, when there is one, is shown to it.
        if [ -S "/run/user/$(id -u)/pipewire-0" ]; then
            pipewire_args="-v /run/user/$(id -u)/pipewire-0:/host-pipewire-0:ro"
        fi
    fi
    : > "$ACTIONS"
    one_installer
    # A fresh, empty file for this step's exit code: a step cut off before it writes one reads as a failure, never as
    # the previous step's 0.
    status=$(mktemp "$WORK/status.XXXXXX") || stop "No room for the installer's notes."
    # shellcheck disable=SC2086
    {
        docker run --rm -i --name agent-installer \
            -v "$AGENTS_HOME:/agents-home" -v /var/run/docker.sock:/var/run/docker.sock \
            $network_args $pipewire_args --user "$user" $group_args \
            -e HOST_HOME -e HOST_PLATFORM -e HOST_NAME -e HOST_TZ -e HOST_LANG -e HOST_LAN \
            -e HOST_UID -e HOST_GID -e DOCKER_GID -e PACKAGE -e KEEPER_USER -e AGENT_USER -e HOST_DNS \
            "$IMAGE" python -u install.py "$@" 2>&1
        echo "$?" > "$status"
    } | read_lines "$ACTIONS"
    stty echo < /dev/tty 2>/dev/null || true       # a step cut off while it hid what is typed
    STEP_CODE=$(cat "$status" 2>/dev/null)
    rm -f "$status"
}

# Docker Desktop: who the keeper and the agent run as, from what the image's user can do (Ruling 16).
run_probe() {
    run_step 1000:1000 probe
    if [ "$STEP_CODE" != 0 ]; then
        step_stopped
    fi
    result=$(sed -n 's/^PROBE //p' "$ACTIONS")
    socket=false
    files=false
    case "$result" in *'"socket": true'*) socket=true ;; esac
    case "$result" in *'"files": true'*) files=true ;; esac
    if [ "$socket" = true ] && [ "$files" = true ]; then
        KEEPER_USER=1000:1000
    else
        KEEPER_USER=0:0
    fi
    if [ "$files" = true ]; then
        AGENT_USER=""
    else
        AGENT_USER=0:0
    fi
    export KEEPER_USER AGENT_USER
}

import_profile() {
    if [ -f "$SCRIPT_DIR/agent.yaml" ]; then
        make_folder "$AGENTS_HOME/import" || stop "The folder for agent.yaml could not be made."
        cp "$SCRIPT_DIR/agent.yaml" "$AGENTS_HOME/import/agent.yaml" || stop "agent.yaml could not be copied."
        own_group "$AGENTS_HOME/import/agent.yaml" || stop "agent.yaml could not be given your group."
    fi
}

start_compose() {
    case "$1" in
        /*|*..*|*[!A-Za-z0-9._/-]*) stop "A step asked to start an unexpected file: $1" ;;
    esac
    docker compose -f "$AGENTS_HOME/$1" up -d < /dev/null || stop "Docker could not start $1."
}

# What a step asked to be done on this computer itself (HOST <action>): only the actions known here.
run_host() {
    case "$1" in
        phone-line) phone_host ;;
        *) stop "A step asked for an unexpected host action." ;;
    esac
}

run_steps() {
    next="start"
    while [ -n "$next" ]; do
        case "$next" in
            *[!a-z0-9\ -]*) stop "A step asked for an unexpected next step." ;;
        esac
        set -f
        # shellcheck disable=SC2086
        run_step "$KEEPER_USER" $next
        set +f
        if [ "$STEP_CODE" != 0 ]; then
            step_stopped
        fi
        # The host part first (it may ask the owner, so the list is on descriptor 3), then the UP lines, then NEXT.
        sed -n 's/^HOST //p' "$ACTIONS" > "$WORK/hosts"
        while IFS= read -r action <&3; do
            run_host "$action"
        done 3< "$WORK/hosts"
        sed -n 's/^UP //p' "$ACTIONS" > "$WORK/ups"
        # The list on descriptor 3, so a stop inside still reads its Enter from the owner.
        while IFS= read -r path <&3; do
            start_compose "$path"
        done 3< "$WORK/ups"
        next=$(sed -n 's/^NEXT //p' "$ACTIONS" | tail -n 1)
    done
}

main() {
    check_user
    check_package
    find_system
    confirm
    prepare_docker
    gather_facts
    make_home
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/install-agent.XXXXXX") || stop "No room for the installer's notes."
    ACTIONS="$WORK/actions"
    # Typed text is shown again however this ends (a Ctrl+C at a hidden prompt included).
    trap 'stty echo < /dev/tty 2>/dev/null; rm -rf "$WORK"' EXIT
    trap 'exit 130' INT TERM HUP
    pull_image
    if [ "$OS" = macos ]; then
        run_probe
    fi
    import_profile
    run_steps
    say "The installer is done."
}

SCRIPT="${LOCAL_AI_AGENT_SCRIPT:-$0}"
SCRIPT_DIR=$(cd "$(dirname "$SCRIPT")" && pwd)
SCRIPT="$SCRIPT_DIR/$(basename "$SCRIPT")"
main "$@"
