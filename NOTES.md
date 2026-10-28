### לבעלים

- "לעדכן עכשיו" מעדכן עכשיו גם את מנהל הסוכנים במחשב, מיד, כשהגרסה צריכה אותו.
- קודם מתעדכן המנהל, ואחריו הסוכן. בינתיים הדף אומר "מתעדכן".

### Technical

`POST /agents/{id}/update` to a release that needs a newer keeper no longer only answers 409: the agent's update is
queued in `keeper.yaml` (`after_swap: {id: version}`, `Store.queue_after_swap`) and `self_update.start` runs at once
(no three-day wait), watched in the background as the night window does. Started: 202 `{"started", "keeper"}`, and a tap
of any agent while the swap runs is queued too. Not started: the entry is taken off again and the answer is 409
`keeper_busy`, `keeper_failed_before` or `needs a newer keeper`. The new keeper runs the queue once at its start
(`run_queued` in `build_app`, after `keep_running`), each agent taken off the queue first, through the button's own
update path; the version answer gives a queued agent as `updating`. The page shows "מתעדכן" while the keeper is silent
right after such a tap (up to `self_update.SWAP_WAIT`), a line for each new refusal, and `OLD_KEEPER_UPDATE` for a 1.6.0
keeper. Protocol stays 4. `KeeperClient.update` answers (answer, version).

Windows and macOS: not tested yet.
