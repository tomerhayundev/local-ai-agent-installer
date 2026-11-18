### לבעלים

- משימה קבועה יכולה לעשות את מה שביקשת במילים שלך: "כל ערב תסתכל על הפגישות של מחר ותגיד לי מה להכין".
- הסוכן קורא רק את מה שהמשימה קוראת, כותב את הדוח, ושותק כשאין מה לספר. טיוטה שהוא מכין יוצאת רק באישור.
- כבוי עד שבוחרים בהגדרות › התראות, תחת "הדוח של משימה קבועה". מודל קטן ממשיך לשלוח את הרשימה הקבועה.

### Technical

#71 (#8's second half). A task keeps the owner's message as its request (`tasks.ask`) when it passes the scan
(`scheduled.request_of`: format characters out, `triage.suspicious`, `noticed.carries_address`), on the draft, on ✅
and before every run; a suggestion's request is never kept. The card shows it while reports are written. A run reads
as v1 does; then, when `proactive.tasks` is `written` and the chat's model profile says `tasks: written`
(`Brain.writes_tasks`; a cloud model writes), one unattended turn (`TaskRunner.write`, `initiator: task`, the request
as the turn's owner words) gets the read lines as data (no line that speaks to an assistant; the emails only while the
mail job's service is the chat's) and writes the report or answers `NOTHING` (nothing sent). Its tools are drafts only,
routed from the request, never a memory or a contact, at most 2. A failed call is the fixed report. Eval set
`eval/task_run_cases.json` with `eval/run_task_eval.py`.

Windows and macOS: not tested yet.
