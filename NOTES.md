### לבעלים

- סוכן חדש שמצטרף לשער הבית משוחח דרך המודל של הבית, ברירת המחדל של השער.
- תפקיד חדש שנותנים לסוכן בשער, למשל ראייה, מופיע בדף שלו בתוך דקה, בלי מפתח חדש ובלי הפעלה מחדש.
- במודל של הבית השער מחליט כמה לחשוב, כל עוד לא בחרתם רמה בדף.
- המודל של הבית יכול לקרוא תמונות כשלסוכן יש תפקיד ראייה.

### Technical

#54. `gate.heartbeat` returns a `Beat` (`next_in`, and `roles`, or None from a gate before 2026-10-30). When the roles
differ from the saved ones, `GateRuntime` reads the description again at once and keeps `you.roles` and their thinking
(`_keep_grant`). The description keeps `picks` (`home-ai` picks from chat, fast and vision). A role with picks is never
asked for at a join, and it satisfies `chat.default_role` when any of its picks is asked for; this fixes joins to a gate
whose default is `home-ai`. A role with picks and no thinking of its own can think as its granted picks can, with the
model's default (nothing sent: the gate's decision model decides). A gate's model list (`ai_lists.gate_list`) is built
from its record, never cached; `vision`, and `home-ai` while the agent has `vision`, take images.

Windows and macOS: not tested yet.
