### לבעלים

- עדכון של סוכן שבוחר מודלים משלו לעבודות (מיילים, תמונות) כבר לא חוזר אחורה בלי סיבה.
- זה קרה כשהשער של הבית שינה משהו בתפקידים של הסוכן בדיוק בזמן העדכון.

### Technical

When a gate's record changes (a role given, or what a role is), the service manager re-switches every job and cancels
each job's own re-fit (`model-fit-<job>`). `/health` let only the chat's cancelled re-fit go (`model-fit`), so it
reported the others as dead loops, and the keeper rolled back every update that met such a change in its watch
(seen 2026-11-04 on 1.14.0 and twice on 1.15.0: dead `model-fit-mail`, `-web`, `-vision`, `-images`).
`Wiring.stopped_on_purpose` now lets every job's cancelled re-fit go; one that stopped by itself is still dead.

Windows and macOS: not tested yet.
