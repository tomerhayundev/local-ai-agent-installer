#!/usr/bin/env python3
"""Pairs the phone with this computer's Bluetooth: started by `phone-line.sh pair` (as root, on the host).

A small BlueZ agent over D-Bus (modelled on BlueZ's own test/simple-agent) instead of text scraped from bluetoothctl:
- It registers an org.bluez.Agent1 object that can show and confirm a passkey (DisplayYesNo), and makes the adapter
  pairable and discoverable for the pairing window only.
- RequestConfirmation(device, passkey) is the one request it can accept. The device is the D-Bus object path BlueZ
  gives (its address is in the path), never a guess from text. It shows the address, the device's name (every control
  and escape character removed, at most 40 characters) and the 6-digit passkey, and asks the computer's owner on the
  terminal to type yes. Only a typed `yes`, inside the window, accepts; anything else, or no answer, rejects. The
  answer belongs to exactly this call.
- It rejects without asking: a pairing with no passkey (Just Works), the legacy PIN and passkey requests, a service
  authorisation from any device but the accepted one, and every request of a second device once one was accepted.
- When the accepted device has paired it turns pairable and discoverable off at once, marks the device trusted, prints
  `ok <address> <name>` and exits 0. When the window ends it exits 1. Another device that pairs meanwhile is removed.
  On every way out (an end, a signal, an error) the agent is unregistered and pairable and discoverable are off.

The keeper's page asks instead of the terminal with `--answers <dir>` (the job's exchange folder, which only the
keeper's user writes; the host helper gives it, `phone-line.sh pair --helper --answers <dir>`):
- When the window opens it writes `<dir>/window.json` {"computer": the adapter's name, "until"}, so the page can say
  which name to choose on the phone and how long is left.
- A RequestConfirmation writes `<dir>/ask.json` {"ask": a new random id, "address", "name" (cleaned), "passkey",
  "until", "computer"} (mode 644, written beside and moved in, so a link planted at the name is replaced, never
  followed) and waits for `<dir>/answer.json` {"ask": that id, "answer": "yes"}: read once (read_answer moves it to
  TAKEN first), only in time (ASK_MAX at most, BlueZ's own limit, and never past the window). A second answer, a
  wrong `ask`, anything but "yes" or a late answer rejects. One answer per window: after a rejection the window ends
  (the owner tries again with a new one), so the page never answers a request it did not show. An answer.json while
  nothing is asked (the keeper's cancel) ends the window too.
- In this mode it also prints `paired <address>` and `adapter <hciN>` for the keeper when the phone has paired.
`--adapter hciN` pairs on that adapter (default: the first BlueZ knows).

The decisions are plain functions (sanitize_name, format_passkey, address_of, decide, service_allowed, options,
read_answer, wait_answer, ask_record, write_json) so that they are tested without D-Bus; the D-Bus and GLib modules
are imported only when the agent runs (python3-dbus and python3-gi).
Nothing here is logged to a file, and the only text printed is this script's own and sanitised names.
Exit codes: 0 paired, 1 no phone paired in the window, 2 it could not run.
"""
import hmac
import json
import os
import re
import secrets
import select
import signal
import sys
import tempfile
import time
from pathlib import Path

AGENT_PATH = "/phone_line/agent"
DEFAULT_SECONDS = 180
MIN_SECONDS, MAX_SECONDS = 10, 600
NAME_MAX = 40
ASK_MAX = 50                      # seconds one question waits at most: BlueZ gives up on a request after about a minute
NO_NAME = "unknown device"
DEVICE_PATH = re.compile(r"/org/bluez/hci[0-9]+/dev_([0-9A-F]{2}(?:_[0-9A-F]{2}){5})")
# CSI sequences (ESC [ ... final), OSC sequences (ESC ] ... BEL or ESC \), and any other two-character escape.
ADAPTER = re.compile(r"hci[0-9]{1,2}")
ANSWER_MAX = 1024                 # bytes of an answer read at most
ANSWER_POLL = 0.5                 # seconds between two looks for the answer
TAKEN = "answer.taken"            # the answer once read: a second one finds it and rejects
ESCAPES = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)?|\x1b[@-_]")


def sanitize_name(text, limit: int = NAME_MAX) -> str:
    """A device's name made safe to print on a terminal: escape sequences removed, then only printable characters kept
    (so no control character, no bidirectional override, no zero-width character), at most `limit` of them."""
    if not isinstance(text, str):
        return NO_NAME
    kept = "".join(ch for ch in ESCAPES.sub("", text) if ch.isprintable()).strip()
    return kept[:limit].strip() or NO_NAME


def format_passkey(value) -> str:
    """The passkey as the phone shows it: six digits, with leading zeros. ValueError for anything but 0 to 999999."""
    if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= 999999:
        raise ValueError("a passkey is a number from 0 to 999999")
    return f"{value:06d}"


def address_of(device_path) -> str | None:
    """The device's Bluetooth address from its D-Bus object path (BlueZ's own, so not the device's word), or None for
    a path that is not a device's."""
    found = DEVICE_PATH.fullmatch(str(device_path))
    return found.group(1).replace("_", ":") if found else None


def decide(kind: str, address: str | None, accepted: str | None, answer, seconds_left: float) -> bool:
    """Whether to accept a request. Only a passkey confirmation (`kind` "confirmation") can be accepted; a device
    with no known address never; a device other than the one already accepted never; nothing once the window is over;
    and the computer's owner's answer must be exactly `yes` (spaces and the line end around it ignored, nothing
    else)."""
    if kind != "confirmation" or address is None:
        return False
    if accepted is not None and address != accepted:
        return False
    if seconds_left <= 0:
        return False
    return isinstance(answer, str) and answer.strip() == "yes"


def service_allowed(address: str | None, accepted: str | None) -> bool:
    """A service authorisation (the hands-free profile, say) is allowed only for the device that was accepted."""
    return address is not None and accepted is not None and address == accepted


def options(argv: list[str]) -> tuple[int, str | None, str | None] | None:
    """(the window, the answers folder, the adapter) from the command line: `[seconds] [--answers <absolute dir>]
    [--adapter hciN]`, each at most once; None for anything else. The window is 180 by default, a whole number of
    seconds from MIN_SECONDS to MAX_SECONDS."""
    window, answers, adapter = None, None, None
    args = list(argv[1:])
    while args:
        arg = args.pop(0)
        if arg in ("--answers", "--adapter"):
            if not args:
                return None
            value = args.pop(0)
            if arg == "--answers":
                if answers is not None or not value.startswith("/"):
                    return None
                answers = value
            else:
                if adapter is not None or not ADAPTER.fullmatch(value):
                    return None
                adapter = value
        elif window is None and arg.isdigit() and MIN_SECONDS <= int(arg) <= MAX_SECONDS:
            window = int(arg)
        else:
            return None
    return (DEFAULT_SECONDS if window is None else window), answers, adapter


def ask_record(ask: str, address: str, name: str, passkey: str, until: float, computer: str) -> dict:
    """What ask.json holds for the keeper's page (the name and the computer's name already cleaned)."""
    return {"ask": ask, "address": address, "name": name, "passkey": passkey, "until": until, "computer": computer}


def write_json(folder: Path, name: str, data: dict) -> None:
    """`data` as <folder>/<name>, mode 644 (the keeper's user reads it): written to a new file beside it and moved in,
    so the folder's other writer can't have it written through a link it planted at the name. Its mode is set on the
    open file, never by its path (the other writer could have put something else there): the path is used again only
    by the move itself. Flushed to disk before the move, so a crash leaves the old file or the new one. A vendored
    copy of app/atomic_write.py (this script runs on the host, outside the image), held to it by
    tests/test_atomic_write.py's one contract."""
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=f".{name}.", suffix=".tmp")     # a new file: O_EXCL
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            if hasattr(os, "fchmod"):                  # every computer the line runs on (Windows has none)
                os.fchmod(file.fileno(), 0o644)
            file.write(json.dumps(data, ensure_ascii=False))
            file.flush()
            os.fsync(file.fileno())                    # on disk before it is swapped in, as atomic_write does
        os.replace(tmp, Path(folder) / name)
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise


def read_answer(path: Path, ask: str, now: float, until: float) -> bool | None:
    """The page's answer to the ask `ask`: True only for {"ask": that id, "answer": "yes"} read in time; None while
    there is none yet; False for a late one (or none in time), a wrong ask, anything but "yes", a file that is no
    answer or a link, and a second answer (TAKEN beside it: the first was read already)."""
    path = Path(path)
    taken = path.with_name(TAKEN)
    if os.path.lexists(taken):
        try:
            path.unlink()
        except OSError:
            pass
        return False
    if not os.path.lexists(path):
        return None if now < until else False
    try:
        os.replace(path, taken)                           # once: whatever comes after it finds TAKEN
        fd = os.open(taken, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    except OSError:
        return False
    try:
        if os.path.islink(taken):                         # no O_NOFOLLOW (Windows): a link is still refused
            return False
        raw = os.read(fd, ANSWER_MAX + 1)
    finally:
        os.close(fd)
    if now >= until or len(raw) > ANSWER_MAX:
        return False
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        return False
    if not isinstance(data, dict) or not isinstance(data.get("ask"), str) or not isinstance(ask, str):
        return False
    return hmac.compare_digest(data["ask"].encode(), ask.encode()) and data.get("answer") == "yes"


def wait_answer(path: Path, ask: str, until: float, *, clock=time.time, sleep=time.sleep) -> bool:
    """Waits for the page's answer to `ask` up to `until`: the first one read decides (read_answer)."""
    while True:
        found = read_answer(path, ask, clock(), until)
        if found is not None:
            return found
        sleep(min(ANSWER_POLL, max(until - clock(), 0.01)))


def say(text: str) -> None:
    print(text, flush=True)


def discard_typed_ahead(tty) -> None:
    """Throws away what is waiting unread on the terminal (termios.tcflush, TCIFLUSH). Best effort: a terminal that can't
    be flushed, or a system without termios, leaves the input as it is."""
    try:
        import termios
        termios.tcflush(tty.fileno(), termios.TCIFLUSH)
    except Exception:                  # noqa: BLE001 - no termios, not a terminal (termios.error is not an OSError)
        pass


def ask_on_terminal(prompt: str, seconds: float) -> str:
    """The computer's owner's typed line from the terminal within `seconds` ("" when there is none, no terminal, or the
    time ran out). It reads /dev/tty, not this script's input, after discarding anything typed ahead."""
    seconds = min(seconds, ASK_MAX)
    if seconds <= 0:
        return ""
    try:
        with open("/dev/tty", "r+", encoding="utf-8", errors="replace") as tty:
            discard_typed_ahead(tty)          # a "yes" typed late for an earlier question must not answer this one
            tty.write(prompt + "\n")
            tty.flush()
            ready, _, _ = select.select([tty], [], [], seconds)
            return tty.readline() if ready else ""
    except OSError:
        return ""


def run(window: int, answers: str | None = None, adapter: str | None = None) -> int:
    """Runs the agent for `window` seconds; `answers`: the keeper's exchange folder (the page answers), `adapter`: the
    one to pair on. The D-Bus pieces are in here so that the module imports without them."""
    try:
        import dbus
        import dbus.exceptions
        import dbus.mainloop.glib
        import dbus.service
        from gi.repository import GLib
    except ImportError:
        say("python3-dbus and python3-gi are missing: run 'sudo bash phone-line.sh setup' first.")
        return 2

    class Rejected(dbus.exceptions.DBusException):
        _dbus_error_name = "org.bluez.Error.Rejected"

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    loop = GLib.MainLoop()
    deadline = time.monotonic() + window
    state = {"accepted": None, "code": 1, "adapter": None, "computer": NO_NAME, "asked": False}
    folder = Path(answers) if answers is not None else None

    def left() -> float:
        return deadline - time.monotonic()

    def device_name(path) -> str:
        try:
            props = dbus.Interface(bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties")
            return sanitize_name(str(props.Get("org.bluez.Device1", "Alias")))
        except dbus.exceptions.DBusException:
            return NO_NAME

    class Agent(dbus.service.Object):
        @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
        def Release(self):
            pass

        @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
        def Cancel(self):
            pass

        @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="")
        def RequestConfirmation(self, device, passkey):
            address = address_of(device)
            try:
                code = format_passkey(int(passkey))
            except ValueError:
                raise Rejected("no")
            if address is None or left() <= 0 or (state["accepted"] is not None and address != state["accepted"]):
                say("A pairing request was refused (not the phone being paired, or the window is over).")
                raise Rejected("no")
            name = device_name(device)
            say("")
            say(f"Pairing request from {name} ({address}).")
            say(f"  Passkey: {code}")
            if folder is not None:
                answer = ask_the_page(address, name, code)
            else:
                answer = ask_on_terminal("Does your phone show the same passkey? Type yes to accept (anything else "
                                         "refuses):", left())
            if not decide("confirmation", address, state["accepted"], answer, left()):
                say("Refused.")
                if folder is not None:                     # one answer per window: the owner starts a new one
                    loop.quit()
                raise Rejected("no")
            state["accepted"] = address

        @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="")
        def RequestAuthorization(self, device):            # a pairing with no passkey (Just Works): never accepted
            say("A pairing that shows no passkey was refused.")
            raise Rejected("no")

        @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
        def AuthorizeService(self, device, uuid):
            if not service_allowed(address_of(device), state["accepted"]):
                raise Rejected("no")

        @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s")
        def RequestPinCode(self, device):
            raise Rejected("no")

        @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u")
        def RequestPasskey(self, device):
            raise Rejected("no")

        @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
        def DisplayPinCode(self, device, pincode):
            raise Rejected("no")

        @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
        def DisplayPasskey(self, device, passkey, entered):
            raise Rejected("no")

    def ask_the_page(address: str, name: str, code: str) -> str:
        """The page's answer through the exchange folder ("yes" or ""), once per window."""
        if state["asked"]:
            return ""
        state["asked"] = True
        ask = secrets.token_hex(8)
        until = time.time() + max(min(left(), ASK_MAX), 0)
        try:
            write_json(folder, "ask.json", ask_record(ask, address, name, code, until, state["computer"]))
        except OSError:
            say("The question could not be put to the page.")
            return ""
        try:
            return "yes" if wait_answer(folder / "answer.json", ask, until) else ""
        finally:
            try:
                (folder / "ask.json").unlink()
            except OSError:
                pass

    def adapter_props():
        return dbus.Interface(bus.get_object("org.bluez", state["adapter"]), "org.freedesktop.DBus.Properties")

    def close_adapter() -> None:
        for name in ("Discoverable", "Pairable"):
            try:
                adapter_props().Set("org.bluez.Adapter1", name, dbus.Boolean(False))
            except dbus.exceptions.DBusException:
                pass

    def on_change(interface, changed, invalidated, path=None):
        if interface != "org.bluez.Device1" or not changed.get("Paired"):
            return
        address = address_of(path)
        if address is None:
            return
        if state["accepted"] is None or address != state["accepted"]:
            try:                                           # a device that paired without being accepted
                dbus.Interface(bus.get_object("org.bluez", state["adapter"]), "org.bluez.Adapter1").RemoveDevice(path)
            except dbus.exceptions.DBusException:
                pass
            say("Another device paired during the window and was removed.")
            return
        close_adapter()                                    # off at once: nothing else may pair
        try:
            dbus.Interface(bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties").Set(
                "org.bluez.Device1", "Trusted", dbus.Boolean(True))
        except dbus.exceptions.DBusException:
            say(f"(The phone could not be marked trusted: run 'bluetoothctl trust {address}' yourself.)")
        name = device_name(path)
        say(f"ok {address} {name}")
        if folder is not None:                             # for the keeper (host_helper's facts)
            say(f"paired {address}")
            say(f"adapter {state['adapter'].rsplit('/', 1)[-1]}")
        say(f"The phone's address: {address}" + (" (the agent's page takes it from here by itself)" if folder is not None
                                                 else ""))
        state["code"] = 0
        loop.quit()

    def tick() -> bool:
        if left() <= 0 or stopped_by_the_page():
            loop.quit()
            return False
        return True

    def stopped_by_the_page() -> bool:
        """An answer with nothing asked (the keeper's cancel) ends the window."""
        return folder is not None and not state["asked"] and os.path.lexists(folder / "answer.json")

    registered = False
    try:
        manager = dbus.Interface(bus.get_object("org.bluez", "/"), "org.freedesktop.DBus.ObjectManager")
        for path, interfaces in sorted(manager.GetManagedObjects().items()):
            if "org.bluez.Adapter1" in interfaces and (adapter is None or str(path) == f"/org/bluez/{adapter}"):
                state["adapter"] = str(path)
                break
        if state["adapter"] is None:
            say("This computer has no Bluetooth adapter that BlueZ knows." if adapter is None else
                f"BlueZ does not know the adapter {adapter}.")
            return 2
        if folder is not None and (not folder.is_dir() or folder.is_symlink()):
            say("The keeper's folder for the answers is not there.")
            return 2
        if folder is not None:                             # a window before this one leaves nothing that counts
            for stale in ("ask.json", TAKEN, "window.json"):     # answer.json: the keeper cleared it; one now is a stop
                try:
                    (folder / stale).unlink()
                except FileNotFoundError:
                    pass
        agent = Agent(bus, AGENT_PATH)
        agents = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
        agents.RegisterAgent(AGENT_PATH, "DisplayYesNo")
        registered = True
        agents.RequestDefaultAgent(AGENT_PATH)
        bus.add_signal_receiver(on_change, dbus_interface="org.freedesktop.DBus.Properties",
                                signal_name="PropertiesChanged", bus_name="org.bluez", path_keyword="path")
        props = adapter_props()
        props.Set("org.bluez.Adapter1", "Powered", dbus.Boolean(True))
        props.Set("org.bluez.Adapter1", "PairableTimeout", dbus.UInt32(window))
        props.Set("org.bluez.Adapter1", "Pairable", dbus.Boolean(True))
        props.Set("org.bluez.Adapter1", "DiscoverableTimeout", dbus.UInt32(window))
        props.Set("org.bluez.Adapter1", "Discoverable", dbus.Boolean(True))
        alias = sanitize_name(str(props.Get("org.bluez.Adapter1", "Alias")), 60)
        state["computer"] = alias
        say(f"On the phone: Settings > Bluetooth > pair a new device > {alias}.")
        if folder is not None:
            write_json(folder, "window.json", {"computer": alias, "until": time.time() + left()})
            say(f"Waiting up to {window} seconds. Keep the phone's Bluetooth screen open, and answer on the page.")
        else:
            say(f"Waiting up to {window} seconds. Keep the phone's Bluetooth screen open, and answer here when asked.")
        for number in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            GLib.unix_signal_add(GLib.PRIORITY_HIGH, number, loop.quit)
        GLib.timeout_add_seconds(1, tick)
        loop.run()
        if state["code"] != 0:
            say(f"No phone paired in {window} seconds.")
        return state["code"]
    except dbus.exceptions.DBusException as e:
        say(f"Bluetooth refused a request ({e.get_dbus_name()}).")
        return 2
    except OSError as e:
        say(f"The keeper's folder could not be written ({type(e).__name__}).")
        return 2
    finally:
        # However this ends: nothing is left pairable or discoverable, and the agent is gone.
        if state["adapter"] is not None:
            close_adapter()
        if registered:
            try:
                dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1").UnregisterAgent(
                    AGENT_PATH)
            except dbus.exceptions.DBusException:
                pass


def main(argv: list[str]) -> int:
    found = options(argv)
    if found is None:
        say(f"Usage: phone-line-pair.py [seconds, {MIN_SECONDS} to {MAX_SECONDS}] [--answers <folder>] "
            "[--adapter hciN]")
        return 2
    return run(*found)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
