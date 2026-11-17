### לבעלים

- מיון מיילים: מייל דחוף נשלח מיד, ומה שיכול לחכות מגיע בסיכום היומי.
- בוחרים בהגדרות › התראות. סוכן קיים נשאל פעם אחת, ועד אז כל מייל נשלח מיד כמו קודם.
- מייל שמנסה לתת הוראות לסוכן לא נקרא במודל: הוא מחכה בסיכום, מסומן כחשוד.
- הסיכום אומר כמה מיילים מוינו הצידה, ורואים אותם בדף.

### Technical

#70 step 3 (#39). `triage.py` routes each new email before anything is pushed: a rule may only send it to the summary
(a calendar answer about an event more than `SOON` away, an automatic reply, list mail); an item that speaks to an
assistant, a label-shaped field included, goes to the summary marked suspicious with no model call; otherwise one
`Brain.label` call (thinking off, temperature 0, log-probabilities, τ 0.9) gives `now`, `digest` or `never`, and a
model's `never` is only listed for mass mail. Unsure goes to the summary unsorted; no answer is pushed as before. The
ledger keeps `decided_by` and `reason`. `gmail.event_start` reads an invitation's `DTSTART`. Settings › התראות asks
once (`proactive.mail`: `sort` / `all`); the template's new agent sorts. Measured on `eval/triage_cases.json` (150
items, labels reviewed) ×3 on the production model: email recall on `now` 1.00, precision at least 0.92, nothing
vanished, no injection pushed (`docs/tuning-log.md`, run 7).

Windows and macOS: not tested yet.
