### לבעלים

- הסוכן עובד כמו קודם: אותם צעדים במחשב, אותה הגדרה של קו הטלפון ואותה בדיקה של כרטיס המסך.
- כשמריצים את קו הטלפון ביד מתוך המתקין, יש לידו עכשיו עוד קובץ אחד שהוא צריך.

### Technical

Issue 72, item 1, stage 4 (host steps): a capability's steps on the computer are declared once, in its manifest's
`host_verbs:` block (its script in the capability's `host/` folder, the files the Linux installer ships, and for each
verb its script command, the arguments it takes from the keeper's records, its time limit, the notice it gives the
agent's chat, the record its run is kept as, and the keeper's own runner or guard for it), read strictly by
`capabilities/host_verbs.py` and listed by `capabilities.host_verbs()`. `HOST_VERBS`, the helper's `COMMANDS`,
`TIME_LIMIT` and per-verb argument branches, `host_steps.CHANGING`, the status-verb loop, `catalogue.STATUS_VERB`,
`build_installers.HOST_FILES` and its modes, and `publish.yml`'s list of executables are drawn from the declarations;
a platform check reads the capability's own (`capabilities.platforms_of`), not `"linux"`. `gpu.sh` moved to
`app/capabilities/ollama/host/`. The scripts' shared shell helpers (`say`, `hint`, `die`, `refuse`, `part`,
`part_done`, `act`, `root_alone`, `put_record`) are one file, `app/capabilities/host-common.sh`: the host helper puts it
before the script on standard input, the Linux zip ships it beside `phone-line.sh`, and a script run from the repo
reads it from there; a helper whose image lacks either file ends at once with code 127 instead of running an empty
script. Every verb's arguments for 4,212 records, its time limit and its notice are equal to 1.30.4's, the
rendered compose files are byte-equal (`scripts/compose_equivalence.py`), and the page is unchanged (the snapshot,
`differing 0`). `test_the_keeper_names_no_host_verb` keeps the keeper's generic code free of any verb, script or
platform.

Windows and macOS: not tested yet.
