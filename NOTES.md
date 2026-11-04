### לבעלים

- הסוכן מקבל מהשער כל מה שבעל השער פותח לו בכרטיס, גם את המסלול הפרטי, בלי עדכון של הסוכן.
- בבחירת מודל מופיע כל תפקיד שהשער נותן, ומתחתיו כתוב בשביל מה הוא.
- כשהשער מפסיק לתת תפקיד שהסוכן השתמש בו, הסוכן עובר למה שנשאר ואומר את זה בצ'אט.

### Technical

The gate is the only judge of what an agent may use: the agent offers every role in `/gate/connect`'s `you.roles`,
`private` and `image` included, and no role is known in code by its name. Gone: `agent_profile.FORBIDDEN_ROLES` (the
profile, the capabilities' manifests and the keeper's `gateway_roles` no longer refuse a name), `gate_runtime.NEVER`,
and `ai_lists`' `GATE_HOME`, `GATE_SEES` and `KINDLESS_NOT_CHAT`. Which roles see pictures is the description's
per-role flag (`gate.SEES`, `sees_images: true` on a `roles[]` entry), kept as the record's `sees`, a role that picks
seeing when one of its granted picks does; a gate that names the flag on no role (today's) is read as before, its
`vision` seeing (`gate.SEES_BEFORE`), so pictures go where they went until the gate says. Each role's `for` words (one line, no control or direction characters,
`gate.FOR_MAX`) are kept as `abouts` and shown under the role's name in the picker (the model fact `about`), and a
job's choice lists every role the gate gives for it that is not in "my models" yet ("השער נותן גם"), so one given later
is there with no search. A role
the gate takes back leaves "my models" at the next read of the description: a job that used it goes back to the
chat's model, the chat moves to the gate's `chat.default_role` (or the first chat role it still gives), and the owner
is told once in the chat (`gate_runtime.gone_words`). Needs the house gate to describe to a known caller every role in
its `you.roles` (private ones too, with `via`, `picks` and the flag); before that, a private role has no `via` and is
not offered. A private role is the model's side only: Telegram and WhatsApp still carry the text.

Windows and macOS: not tested yet.
