### לבעלים

- סוכן שמחובר לשער שולח לו את השם הנוכחי שלו.
- אחרי שינוי השם בדף, מי שמנהל את השער רואה את השם החדש ויכול לבחור בו.

### Technical

A joined agent's heartbeat (`POST /gate/heartbeat`, gate-connect section 5) carries `label`: its name now
(`profile.assistant_name`, its whitespace made one space), cut to the description's `heartbeat.body.label_chars` and
never longer than the format's label (`gate.LIMITS`). It goes only to a gate that names `label_chars`
(`gate.Description.label_chars`, 0 when it names none): an older gate, which may refuse a field it doesn't know, gets
the same body as before. A rename on the page is the keeper's settings job, which restarts the agent with its new
profile, so the first beat after it has the new name; the gate never renames the agent by itself, and whoever runs the
gate may take the name. The runtime reads the description with the key at the join, at the heartbeat loop's start and
every `DESCRIBE_EVERY`, so a gate updated while the agent runs gets the label too; a read that fails keeps the last
answer until the next one. Nothing else new is sent: no address, no secret, no message text.

Windows and macOS: not tested yet.
