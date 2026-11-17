### לבעלים

- משימות קבועות: מבקשים בצ'אט דוח קבוע, למשל "כל יום ראשון בשמונה תשלח לי מה יש ביומן ומה הגיע במייל".
- הסוכן מראה את המשימה בשורה אחת, והיא נשמרת רק אחרי ✅.
- הדוח מגיע בזמן, מיד או בסיכום, לפי ההגדרות של התראות. כשאין מה לדווח לא נשלח כלום.
- רואים, משהים ומבטלים משימות בצ'אט ובעמוד של היכולת. היכולת כבויה עד שמתקינים אותה.

### Technical

#70 step 4, #8 v1. The capability `scheduled_tasks` (off by default) adds `create_task` (action: a code-written ✅
card, saved on ✅ and checked again then), `list_tasks` (read), `pause_task` and `cancel_task` (own). A task is a set of
parts (calendar and reminders for the window ahead, the mail the mail watch stored for the window behind, optionally
only mail naming its words), daily, weekly or monthly, at most 10. `scheduled.py` claims each due slot in one update
that moves the next slot on, reads in code (no model, no tools), and hands the report to the proactive ledger
(`initiator: task`, kind `scheduled_task`, `now` or `digest` by the task); nothing found is a `log` row only; a part
that can't be read is said; a run that read nothing retries at 5/15/30 minutes, and 3 failed slots in a row tell the
owner once; a slot later than half its period is skipped and a resumed task gets one catch-up. `Tools.initiator`
holds unattended runs to `read` tools and ✅ drafts, with `own` and the task tools blocked; another agent's turn never
touches the tasks. Routing offers the task tools alone for a standing report ("כל … תשלח לי"), never with a reminder
word, and never to a message that names no topic. The page lists, pauses, resumes and cancels tasks on the
capability's page. Eval cases 108-115, held-out h123-h125.

Windows and macOS: not tested yet.
