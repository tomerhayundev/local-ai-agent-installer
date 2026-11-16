### לבעלים

- בהגדרות יש מקום חדש, "התראות": הסיכום היומי, שעות שקט, כמה הודעות ביום לכל היותר, ומה לעשות עם מייל חדש.
- רואים שם מה הסוכן שלח לאחרונה, מה מחכה ולמה.
- סוכן קיים ממשיך בדיוק כמו קודם עד שמשנים משהו שם.
- הסיכום היומי אומר כשלא הצליח לבדוק את היומן, ומונה מה חיכה לו.

### Technical

#70 steps 1 and 2. Every unasked item (an owner's reminder and its nag, the daily summary, a new email) is a row of one
ledger table, `proactive` (`UNIQUE(source, dedup_key)`, db/proactive.py), sent by one sender (proactive.py). A source
keeps its watcher and is asked back by name (`still`, `settled`, `failed`, `retry_at`), with today's timing for each.
A restart never sends a row twice; a row a restart left `sending` is sent after it. The rules (proactive_policy.py)
only lower an item: a ceiling per kind (`log` < `digest` < `now` < `call`; `call` is sent as `now` until the phone
ladder), quiet hours, and a daily cap whose overflow waits for the summary; reminders and the summary are exempt. The
profile's new optional `proactive` section (`quiet`, `cap`, `kinds`) holds them; with none, nothing changes. A new
agent's template sets quiet hours 22:00-07:00 and a cap of 5. The keeper may set `proactive.quiet`, `proactive.cap`
(a number) and `proactive.kinds.<kind>`. Settings' summary group is now `proactive` (/connect/settings/proactive),
with the rules' form and the ledger's recent log. An email no channel could take is retried with its notice as it
was made (the model's line), no longer rebuilt from its first words.

Windows and macOS: not tested yet.
