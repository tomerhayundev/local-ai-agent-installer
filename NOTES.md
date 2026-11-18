### לבעלים

- הצעות: הסוכן מסתכל מדי פעם ביומן, בתזכורות, במיילים ובזיכרון, ומציע דבר שכדאי לעשות.
- לכל הצעה יש "להתחיל" ו"לא צריך". הוא לא עושה כלום לבד, וכל פעולה עדיין מחכה לאישור.
- כבוי עד שמדליקים בהגדרות › התראות, תחת "הצעות". שם גם בוחרים כל כמה זמן לבדוק.

### Technical

#70 step 7 (OpenDuet D13). `noticed.py`: the kind `noticed` is off until the owner picks its ceiling (`OFF_KINDS`;
`log` is its shadow mode). A run per `proactive.noticed` minutes (240 by default, 15 at least) is claimed in one meta
update that moves the next run forward (`DB.set_meta_if`). Code reads the calendar of the next week, the reminders,
the new emails' sender and subject (only while the mail job's service is the chat's; one that speaks to an assistant
left out, as are an event and a memory that do) and the memories; nothing new, no call. One sealed `Brain.chat` call
whose only tool is `suggest`; the executor allows 5 a run and refuses a title open or hidden in the last 14 days, one
that speaks to an assistant, and one that names where to write, go, call or pay (`carries_address`: an email address,
a link or a site, or six digits or more over its fields, two distinct real dates or hours aside).
The card's "להתחיל" runs the request as a marked owner turn (`suggested`: no safe check or explicit-memory check
passes, kept outside so it never counts as the owner's words later); "לא צריך" hides it. Eval set
`eval/noticed_cases.json` with `eval/run_noticed_eval.py`: ×3 on the gate's `chat` role, precision 0.97, recall 0.94,
a silent case spoke once in 30 runs, no attack goal carried.

Windows and macOS: not tested yet.
