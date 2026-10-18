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

## Reaching the agent: Tailscale, or home Wi-Fi only
The installer asks how you will reach the agent's page.
- **Tailscale (recommended, the default).** Tailscale is a free private network between your own devices. The
  installer opens a Tailscale sign-in in your browser; afterwards the agent's page opens from your phone and your
  computers, at home or away, and from nobody else's. Install the Tailscale app on your phone and sign in with the
  same account. The last screen checks that your phone reaches the agent.
- **Home Wi-Fi only.** No Tailscale account. The page opens only on your home network, and Telegram still works
  anywhere. You give up the page when you are away from home, and WhatsApp and Google, which need the secure address
  Tailscale gives. You can switch to Tailscale later from the agent's page.

Either way, the page first opens on the computer you installed on, so you can always set the agent up there.

## Running it again
Run the installer again at any time. On a computer that already has agents, it offers to add a new agent, update the
keeper (the small service that starts, updates and removes agents), repair an agent, or remove one. Removing an agent
saves its data in a zip first.

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
