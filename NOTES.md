### לבעלים

- שינוי פנימי, בלי שינוי בדף: מה שהטלפון עושה בעבודות של המחשב כתוב עכשיו במקום אחד משלו.
- הוספת טלפון והסרתו עובדות כמו קודם, באותן מילים.

### Technical

Issue 72, item 4, stage 2: the phone's part in the jobs' lifecycle is its manifest's. A manifest names its keeper
module (`keeper:`, a module of `app/keeper/`, its own code without a `code:` line), holding only hooks of the closed
table `keeper/jobs/kinds.py` `LIFECYCLE` (`actions`, `UNLESS`, `REVOKES`, `HOST_REMOVALS`, `check`, `on_start`,
`on_load`, `PRIVATE_KEYS`, `on_end`, `waits`, `busy_steps`, `release`, `removal`), which `Jobs` collects from the
catalogue it is made with. Every phone branch of `keeper/jobs/` and `keeper/preset_job.py` is a hook call now (the
removal's hint and pairings, `line_before` in one place, the pairing reset at load, the records' private keys, the new
line key revoked at a bad end, the line's busy steps, a removed agent's checks, what a removal would take). The
phone's `add`, `drop` and `release` are declared `jobs:` of the one `capability` kind (`release` with
`after_removal: true`: started only by the phone's `release` hook, skipping the refusals that need the agent's record,
and resumed without it); the `phone` job kind is gone, and a job record of it ends `unknown_kind`. A declared job's
audit line names its capability (`phone.add`, `ollama.restart`). The queue's phone line is one line per capability
with `waits` (`*phone`). The page's words for a phone added or removed come from the manifest (`PHONE_ADD`,
`PHONE_DROP`, `PHONE_RELEASE`); as every capability's own job, a failed phone add or drop whose step ran no longer
says nothing changed. A removed agent's checks never raise out of its removal (a refused one is logged).
Splits by responsibility: `capabilities/presets.py` (out of `capabilities/__init__.py`),
`keeper/line_steps.py` into the line's records (`line_steps.py`), its jobs' steps (`line_actions.py`) and its hooks
(`line_hooks.py`), and `keeper/jobs/records.py` (the mixin of a job's record). `keeper/jobs/` names no capability and
imports none of its modules: no pin left there. The guards: 216 names in 56 files (218 before), 84 imports in 34
files (92 in 38). The page snapshot against 1.30.7 shows no difference but the known timing noise.

Windows and macOS: not tested yet.
