### לבעלים

- הסוכן עובד בדיוק כמו קודם: אותן יכולות, אותו דף ואותן תשובות.
- השינוי בפנים: מה שאפשר להדליק, להשהות ולהפעיל ברקע נקרא עכשיו מההגדרה של כל יכולת, במקום אחד.

### Technical

Issue 72, item 1, stage 2 (the switch): what a profile can switch, level and pause, what is built and which background
loops run are drawn from the manifests. `manifests.py` (no app import) reads each manifest and its switch (`profile`,
`pausable`, `order`) below the profile reader, and the catalogue reads through it, so the old import cycle never forms.
`BOOL_CAPABILITIES` and `PAUSABLE` come from it (`ollama` declares `pausable: false`); the profile's per-capability
fields became one mapping, `Profile.capabilities`, read as attributes as before, with `Profile.on`.
`LATER_CAPABILITIES` keeps only the keys an older template wrote (`cameras`, `expenses`), accepted off, so every
existing agent still loads; the template now lists exactly the catalogue's switches. `Wiring.on` is what is built
(switched on, not paused, every credential ready), replacing `CAPABILITIES` and the `*_on` flags; a capability declares
its loops (`loops:`, `capabilities.LOOP_NAMES`) and `main.py` starts them from `CAPABILITY_LOOPS`. `Tools` takes the
switch (`on`), so `tools/__init__.py` names no capability (the guard now says so). The start log lists what is built.
The catalogue's `except CatalogueError` in the wiring, which could not keep the agent up, is gone. Nothing the model
sees changed (`scripts/tool_equivalence.py`, 62,160 cases, byte-equal), nor the page (the snapshot, `differing 0`).

Windows and macOS: not tested yet.
