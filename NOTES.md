### לבעלים

- סוכן שמחובר לשער מספר לו באילו ערוצים אפשר לפנות אליו, למשל טלגרם או וואטסאפ.
- מי שמנהל את השער רואה את הערוצים האלה במפה, עם קו מכל ערוץ אל הסוכן.

### Technical

A joined agent's heartbeat (`POST /gate/heartbeat`, gate-connect section 5) carries `channels`: the channels the owner
switched on (`telegram`, `whatsapp`; the messenger's channels, connected or not, since each one's health is already its
part), sorted, each matching the format's channel name and cut to the description's `heartbeat.body.channels_max`
(never more than `gate.CHANNELS_MAX`). An empty list says the agent has none now. It goes only to a gate that names
`channels_max` (`gate.Description.channels_max`, 0 when it names none): an older gate gets the same body as before. The
description is read as for the label (at the join, at the heartbeat loop's start and every `DESCRIBE_EVERY`). Nothing
else new is sent: a channel's name only, never an address, a number or a message.

Windows and macOS: not tested yet.
