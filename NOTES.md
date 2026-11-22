### לבעלים

- סוכן עם חיפוש באינטרנט מקבל את אייקון החיפוש, וסוכן עם מייל בלבד את אייקון המייל.
- כשמגדירים את כרטיס המסך למודלים שרצים אצל הסוכן, או מפעילים אותם מחדש, דף היכולת מראה את ההתקדמות.

### Technical

Issue 72, item 4, stage 1: generic code names no capability where item 4 points, and the rest is measured. A
manifest's `code:` names the capability's own modules (never one of the generic hubs, `capabilities/own.py`
`GENERIC`), and two guards pin what generic code still names or imports of a capability:
`test_generic_code_names_no_capability` (`NAMED`, per module and name: 245 names in 59 files at the start, 218 in 56
now) and `test_generic_code_imports_no_capability_module` (`IMPORTS`: 95 imports in 38 files, 92 now); each pin only
goes down, and the claims themselves are pinned beside them (`CLAIMED`), none covering a pinned module. A manifest's `jobs:` declares the capability's own jobs, actions of the one `capability` job kind (steps by
the one Need parser, words named in `words/capabilities.py`, `args`, `protocol`), refused by `catalogue.refusal`
(version, platform, host steps when a step is one, `not_installed`) and asked again when their turn comes (a queued
job whose capability went ends `failed` `not_installed`, a new job end). Ollama's three card jobs move into its
manifest, `keeper/ollama_jobs.py` goes, and `POST /agents/{id}/ollama` starts a capability job; a job record of the
old `ollama` kind ends `unknown_kind`. The job kinds are one registry, `keeper/jobs/kinds.py` `KINDS`; the phone's
entry is registered by `keeper/line_steps.py` until stage 2. `keeper/jobs/` names no capability (10 names to 0), and
`pages/running/` keeps a job of any kind with no list of kinds (7 to 0). The agent's icon is its ranked capability's
own `icon` (`icon_rank`: phone 10, calendar 20, email 20, home 30, web 40; `capabilities.agent_icon`, `own_icon`, a
paused capability counting), replacing `page_shell.KIND_ICONS`, `kind_icon`, `my_icon` and `shown_icon`. The
platforms' names are one table, `capabilities.PLATFORM_NAMES`. The page snapshot against 1.30.6 differs only in those
two icons.

Windows and macOS: not tested yet.
