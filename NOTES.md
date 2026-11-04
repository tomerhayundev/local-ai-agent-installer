### לבעלים

- פעולה שמבקשים כשהסוכן עסוק כבר לא נדחית: היא נכנסת לתור ומתחילה לבד כשהוא מתפנה.
- זה כולל התקנה, הסרה והשהיה של יכולת, שינוי הגדרות, עדכון, הפעלה מחדש והסרה של סוכן.
- כמה פעולות שמחכות רצות לפי הסדר שביקשתם, ואפשר לבטל פעולה שעוד מחכה.
- עדכון של סוכן יחד עם הסוכנים המשניים לא מעדכן שוב סוכן שכבר הגיע לגרסה.

### Technical

The keeper never refuses an action because the agent is busy. A job asked for while the agent has a job of its own, or
is held in `Updater.busy`, waits on its agent's line (`keeper/jobs/queue.py`, `JobQueue`: `queued` is its place, its
state `running` with every step `waiting`), kept across a keeper restart, started when the agent's job ends or the hold
lets it go (`Busy.on_free`); cancel() ends a waiting job at once. A profile step waits for a hold as long as it lasts
(`BUSY_WAIT` is gone). The update, restart and removal routes answer 202 `{"queued": true}` while the agent is held and
run once it is free (`ApiState.claimed_later`); a second tap of one action while it waits adds nothing, a waiting
update whose agent reached the version moves nothing, and while the keeper replaces itself they stay 409 busy. The one
`busy` left is the line's (a phone install while another agent's removal may take the line down, or a pairing). #57: a
tree run reads the agent's version again before each try, so an agent that reached the version meanwhile is `done`,
not moved again. The capability page says a waiting job waits its turn (`capabilities.QUEUED`). A waiting action is
bound to the agent it was asked for (its record's `made`): when its turn comes, a missing agent or another one under the
same id ends it (`no_agent`; the routes' waits end quietly), a capability change is refused again as at its start
(already made: `done`), and nothing new waits on an agent being removed (409 busy).

Windows and macOS: not tested yet.
