### לבעלים

- סוכן שמחובר לשער מספר לו גם מי הסוכן הראשי שלו, מי סוכני המשנה שלו ומי עמיתיו.
- הוא מספר גם מה הוא עושה ואילו יכולות פועלות אצלו, כמו שהם עכשיו.
- מי שמנהל את השער רואה במפה את סוכני המשנה מתחת לסוכן הראשי שלהם.

### Technical

A joined agent's heartbeat (`POST /gate/heartbeat`, gate-connect section 5) carries `agent_id` (its own id) and
`links`: each linked agent once, sorted by id, as `{agent, is, name}`, where `is` is what the other agent is to this
one (`main`, `sub` or `peer`: this agent's role on the link turned round, `gate_runtime.OTHER_IS`) and `name` its card's
name on one line, cut to the format's label. Every link the keeper handed out (the link book), the owner group's or
not; never a key, a link id, an address or an owner. Ids the format doesn't take (`gate.AGENT_ID`) are skipped, and
none of it is sent when the agent's own id doesn't fit. With them go `purpose` (the profile's one line, cut to
`purpose_chars`; "" says none) and `capabilities` (installed and not paused, sorted, the format's names only, cut to
`capabilities_max`). All of it is read anew on every beat: the links from the book (a keeper `card` notice refreshes
it), the purpose and the capabilities from the profile the agent runs with (a change on the page restarts it). It goes
only to a gate that names `heartbeat.body.links_max` (`gate.Description.links_max`, at most `gate.LINKS_MAX`;
`purpose_chars` and `capabilities_max` likewise, each only when named): an older gate gets the same body as before.
The description is read as for the label and the channels.

Windows and macOS: not tested yet.
