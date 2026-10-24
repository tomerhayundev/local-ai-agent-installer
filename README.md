# Local AI Agent installer

This installs a personal AI agent on your own computer: it runs in Docker, you talk to it on Telegram, and you set it
up on its own page. The installer sets up Docker if it is missing, asks a few questions, and opens the agent's page in
your browser when it is done.

**Download** the zip for your system from the [latest release](../../releases/latest):

| System | Download | Then |
|---|---|---|
| Windows 11 | `install-windows.zip` | double-click `install-agent.cmd` |
| macOS | `install-macos.zip` | right-click `install-agent.command`, then Open |
| Linux | `install-linux.zip` | `sh install-agent.sh` |

Unzip it first: the installer needs the files next to it.

**Windows and macOS: not tested yet.** So far only Linux has run this installer. The Windows and macOS installers are
built to work, and each system leaves this line once a run on it passes.

## Windows
1. Unzip `install-windows.zip`, then double-click `install-agent.cmd`.
2. Windows SmartScreen may warn that the file is from an unknown publisher, because it isn't signed. Click
   **More info**, then **Run anyway**.
3. When Docker Desktop is missing, the installer installs it (and WSL2, when that is missing too). Windows asks for
   administrator rights for this, and may need a restart: after you sign in again, the installer carries on by
   itself.

## macOS
1. Unzip `install-macos.zip`.
2. The first time, **right-click** `install-agent.command` and choose **Open**, then **Open** again: macOS asks
   because the file isn't signed. After that a double-click is enough.
3. When Docker Desktop is missing, the installer installs it, with Homebrew if you have it, or from Docker's own disk
   image.

You can also run it from Terminal: `sh install-agent.sh` in the unzipped folder.

## Linux
Unzip `install-linux.zip` and run, in that folder:

    sh install-agent.sh

Run it as yourself, not with sudo: it asks for your password when it needs it. When Docker is missing, it installs
Docker Engine and its Compose plugin from Docker's own repository, and adds you to the `docker` group. It does that
on Ubuntu and Debian (and systems built on them); elsewhere, install Docker Engine and its Compose plugin first, then
run the installer.

Or all in one line in a terminal, where `<latest>` is this repository's address followed by
`/releases/latest/download` (the download links of the [latest release](../../releases/latest) start with it):

    curl -fsSLO <latest>/install-linux.zip && unzip install-linux.zip && sh install-agent.sh

A model server on this same computer (Ollama, say) is reached from the agent at `host.docker.internal`. Two things
have to let it through: the server must listen on more than `127.0.0.1` (for Ollama, `OLLAMA_HOST=0.0.0.0`), and a
firewall such as ufw must let Docker's networks in to its port. For Ollama's port, with ufw:

    sudo ufw allow from 172.16.0.0/12 to any port 11434 proto tcp

`172.16.0.0/12` is where Docker puts its networks by default; if yours are set elsewhere, use that range.

## A phone line (Linux only)

An agent can place a phone call for you, with your approval each time, through an Android phone that stays near the
computer (a SIM, a charger, Bluetooth range). Best is a phone used only for the agent: the installer asks, and with yes
(the default) the phone stays connected, which is what every call's audio has needed so far. Your everyday phone works
too, connected only for a call, but that is experimental: a call's audio may stay on the phone, and then the callee
hears nothing. Run the installer as usual (`sh install-agent.sh`) and choose
**A phone agent** as the kind of the new agent. It installs everything the agent needs, in one flow:

1. This computer: Bluetooth, oFono and PipeWire, with `phone-line.sh` (it sits next to `install-agent.sh`, with
   `phone-line-pair.py` and `phone-line.apparmor`, the line's own AppArmor profile, which it loads on a computer with
   AppArmor). The installer runs it with sudo, so it may ask for your password. What is done already is
   skipped: a second phone agent sets nothing up again.
2. Pairing the phone, unless it is paired already: on the phone, Settings, Bluetooth, pair a new device, and pick this
   computer. Both screens show the same 6-digit code: check it, then type yes in the installer.
3. A test call, only if you want one: the installer asks, and calls only when you type yes and then your own number.
   It has no AI: it rings you, plays a tone and listens for 5 seconds.
4. The agent's questions (name, your name, language, time zone, how you reach it), then the voice service and its key
   (typed hidden, kept in a private file), and whether the phone is used only for the agent. A line set up already is
   reused: the new agent only gets its own key, and the phone question is asked again with your answer as the default.
5. The line starts, the installer says whether it is ready, and the agent's sign-in and page follow as usual.

To give the phone to an agent you already have, choose **A phone line** in the installer's menu (Linux only).
Each part also runs by hand: `sudo bash phone-line.sh setup`, `pair`, `check`, `status` (what is done already) and
`test-call <your own number>`.

## Reaching the agent: Tailscale, or home Wi-Fi only
The installer asks how you will reach the agent's page.
- **Tailscale (recommended, the default).** Tailscale is a free private network between your own devices. The
  installer opens a Tailscale sign-in in your browser; afterwards the agent's page opens from your phone and your
  computers, at home or away, and from nobody else's. Install the Tailscale app on your phone and sign in with the
  same account. The last screen checks that your phone reaches the agent.
- **Home Wi-Fi only.** No Tailscale account. The page opens only on your home network, and Telegram still works
  anywhere. You give up the page when you are away from home, and WhatsApp and Google, which need the secure address
  Tailscale gives. There is no switch to Tailscale later: that means removing the agent (its data is saved as a zip
  in `removed/`, not brought back by itself) and installing it again with Tailscale.

Either way, the page first opens on the computer you installed on, so you can always set the agent up there. At the
end of a Tailscale install, after the phone check, the installer gives one more link to the page for your computer
(it works once, within 24 hours).

### Tailscale: the agent's tag and your tailnet's access policy
An agent's device signs in with the tag `tag:agent`, so a tailnet's access policy can say who reaches it and what it
reaches. Whoever signs it in (the installer opens the sign-in) must be an owner of that tag. With the policy Tailscale
starts every tailnet with, the tag has no owner yet: the installer then signs the device in without it and prints
the lines below. To tag agents, the tailnet's admin adds them to the policy file
(https://login.tailscale.com/admin/acls/file), then gives an untagged agent the tag in the admin console's list of
machines:

    "tagOwners": {"tag:agent": ["autogroup:admin"]}

and, in the policy's `"grants"` list, your devices to the agent's page (port 8443), and the agent to a home gate's AI
port only (`tag:gate` stands for your gate's own tag, or its 100.x address; leave this one out without a home gate):

    {"src": ["autogroup:member"], "dst": ["tag:agent"], "ip": ["tcp:8443"]}
    {"src": ["tag:agent"], "dst": ["tag:gate"], "ip": ["tcp:11434"]}

A tagged device doesn't sign out when its key would expire, and belongs to the tailnet rather than to one person.

### Tailscale: names on the tailnet, inside the agent
Inside the agent, names on the tailnet (a home gate's `https://<gate>.<tailnet>.ts.net:11434`) are looked up through
Tailscale, and every other name through this computer's own DNS servers, which the installer finds on Linux. When it
finds none (and always on Windows and macOS for now), it says so, and the agent reaches tailnet devices by their
100.x address instead. No public DNS server is ever put in their place.

## Running it again
Run the installer again at any time. On a computer that already has agents, it offers to add a new agent, update the
keeper (the small service that starts, updates and removes agents), repair an agent, remove one, or get "A link to an
agent's page": a fresh one-use link (24 hours) to a running agent's connections page, with the phone's QR code for a
Tailscale agent, for when no chat is connected. It changes nothing else: no restart, no file written. Removing an
agent saves its data in a zip first.

## Your data, and the terms
- **As is, at your own risk.** The software comes as is, without any warranty, and you use it at your own risk. The
  license's own terms say the same.
- **Nothing goes to the publisher.** Neither the installer nor the agent sends usage data, or anything else, to the
  publisher. Your agent's data stays on your own computer.
- **Your own accounts.** You use your own accounts with the services you connect (Tailscale, Telegram, AI providers,
  Google), under those services' terms. Docker Desktop has its own license, free for personal use (and for
  small businesses under Docker's terms); the installer shows its link before it installs anything.
- **The license.** Free for personal use and other noncommercial purposes under the
  [PolyForm Noncommercial License 1.0.0](LICENSE), and nobody may sell it. Other people's software inside the agent
  keeps its own license: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) lists it.
