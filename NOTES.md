### לבעלים

- להודעות של המעקב ביומן ובבית יש עכשיו 👍 ו"פחות כאלה".
- "פחות כאלה" שולח את הסוג הזה רק לסיכום, עד שבוחרים אחרת בהגדרות › התראות.
- בהגדרות › התראות רואים מתחת לכל סוג כמה הודעות עזרו, והצעה לסיכום כשרובן לא עזרו.
- שום דבר לא זז לבד.

### Technical

#70 step 8. `reactions.py` keeps the owner's reaction in each pushed row (`reaction`): `tapped` (an item's own button
or 👍), `dismissed` (an email's ignore), `less` ("פחות כאלה"), and `ignored`, computed a day after a send with no
reaction. A watcher's item gets 👍 / "פחות כאלה" (`rx:up|less:<id>`) when the ledger sends it; an email keeps its own
buttons. "פחות כאלה" latches the kind (meta `proactive_less`), and `decide` sends it to the summary (reason `less`)
until the owner saves the kinds' choices on the page. The page shows, under each kind, how many helped and suggests the
summary when at most a fifth of at least 5 helped.

Windows and macOS: not tested yet.
