### לבעלים

- הסוכן עובד בדיוק כמו קודם: אותם כלים, אותן תשובות ואותם אישורים.
- השינוי בפנים: כל יכולת מוגדרת עכשיו במקום אחד, כך שיכולות חדשות יגיעו מהר יותר.

### Technical

Issue 72, item 1, stage 1: every fact about a tool (its class, approval kind, `private`, `outside`, `owner_only`,
timeout, `words_only`, `with_calls`, `held_until_asked`, `secret_args`, levels) and each capability's routing topics are
declared only in its manifest (`capabilities/tool_facts.py` reads them; a fact left out takes the safe side). `Tools`
and `routing.py` read them through `capabilities.catalogue`, `tool_facts`, `own_tools` and `tools.facts`; a rule of one
capability is a route hook in its own tools module (`route:` in its manifest: `alone`, `topic`, `after`, `last`,
`message`, `outward`). Gone: `CLASSES`, `APPROVAL_KIND`, `CAPABILITY_TOOLS`, `PRIVATE_READS`, `OUTSIDE_TOOLS`,
`MEMORY_TOOLS`, `TIMEOUTS`, the per-family lists and the executors' dict (an executor is `_run_<kind>`). Nothing the
model sees changed: `scripts/tool_equivalence.py` gives the same picks and schemas, byte for byte, on 62,160 cases
(12 agent shapes, both fits, with and without a call in hand, every eval message, every routing test's text and every
pair of two topics' words). A narrower lookup's topic (`narrow`: free time, a saved address) comes after every
capability's main topics, as before; a tool's `secret_args` left out means its arguments are never logged.

Windows and macOS: not tested yet.
