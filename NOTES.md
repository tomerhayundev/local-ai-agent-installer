### לבעלים

- כשמשהו אחר רץ ושינוי לא יכול להתחיל, הדף אומר מה רץ ועד מתי, עם קישור אליו.
- בהגדרות יש "מה רץ עכשיו": כל שינוי שרץ, עד מתי, איפה מסיימים אותו, ו"לבטל" כשאפשר.
- בעדכונים רואים את הגרסה של מנהל הסוכנים במחשב, ולמה היא יכולה להיות אחרת.
- "לעדכן גם את הסוכנים המשניים": קודם הם, אחד אחרי השני, והראשי אחרון. סוכן של בעלים אחרים מחכה לאישורם.
- העדכון האוטומטי בלילה לוקח איתו גם את הסוכנים המשניים, ואפשר לכבות את זה.

### Technical

#44 (the rest of it) and #48. Keeper protocol 6 (`keeper/store/base.PROTOCOL`, `page_http.PROTOCOL`): a keeper that
speaks 5 replaces itself before an agent moves to 1.8.0.

What runs now: `GET /agents/{id}/running` (keeper/running.py) lists, from the keeper's own records only, the agent's
job that has not ended (whatever page started it), the computer's link job touching it, an update moving it (with the
end of its watch), a tree run it is in, the keeper's own swap, what else holds it in `Updater.busy` (each hold now says
what it is: `Busy.hold(agent, what)`, `HOLDS`), and another agent's phone removal that may take the line down. It
reads only. The page's new part `pages/running/` draws it as the settings group "מה רץ עכשיו" (a live region; "לבטל"
is the keeper's existing job cancel), adds one "info" line on home while something runs, and names it in every busy
refusal: `page_http.busy_note` (the settings, capability, phone, agents, new-agent and updates parts) asks the part for
what runs and links to the group. `GET /protocol` also gives the keeper's own `version`, and `GET /version` gives
`keeper: {version, protocol, update_to, update_at}`: the release it will replace itself with and when
(`schedule.keeper_due_at`, the night window's rule), shown under the agent's version with why they may differ.

The tree: `POST /agents/{id}/update/tree` moves the agent and its sub-agents (the store's `sub` links, depth 1) to the
newest release, one at a time, the sub-agents first (its owner group's by id, then other owners') and the agent
last; agents on it already are left out. A run is kept in `keeper/tree.json` (keeper/tree.py `TreeRuns`), so a keeper
restarted part way goes on (`resume`, at its start, after the jobs); each agent moves through the API's one update
path (`updates_api.update_one`: the button's `run_update`, its hold, its record and its cleanup). A sub-agent of
another owner group waits for that owner's ✅ in its own chat: a new relations request kind `update` (with
`version`, Ruling R43), whose card is the link request's; a no or a day without an answer leaves that agent and goes
on. The first `went_back` (or a failure before any change) stops the run before the agent's own update. A release
that needs a newer keeper records the run and swaps the keeper first; the new keeper runs it. `GET`/`DELETE
/update/tree` read and stop a run; `GET /version` adds `subs` ({id, name, running}), `tree` and `auto_tree`. The
night window (`schedule.window`) runs the tree for an agent with automatic updates on, `auto_tree` on (the entry's new
field, true by default) and sub-agents, and leaves those agents to it; a night's run also leaves out an agent whose
`failed` has the version. `PUT /auto` takes `{"tree": bool}`. The updates group offers the second choice beside
"לעדכן עכשיו" (the sub-agents behind, with the version each runs), says on an up-to-date agent which sub-agents are
behind (and on home), shows the run's agents in a live region with "לעצור", and has the night option beside
"עדכון אוטומטי". Not done: a sub-agent on another computer (every link is one keeper's, so a tree is one computer's).

Windows and macOS: not tested yet.
