### לבעלים

- יכולת חדשה: יצירת תמונות. כותבים "תצייר לי קוף על עץ", והתמונה מגיעה בצ'אט כתמונה, לא כקישור.
- את המודל שיוצר תמונות בוחרים בדף, בכרטיס "יצירת תמונות": תפקיד התמונות של שער הבית, או מודל של שירות.
- תפקידי התמונות של השער מופיעים בדף, ורק כמודלים שיוצרים תמונות, לא כמודלי שיחה.
- כשאי אפשר ליצור תמונה, למשל כשהתחנה של הבית כבויה, הסוכן אומר את זה במילים פשוטות.

### Technical

House #211 (the image lane), the agents' side. The gate's description says each role's kind (`Description.kinds`:
`via`, and `image` for a role its `images.generations` block names) and where images are made
(`Description.images`); the gate's record keeps `kinds` and `images_path` beside the roles, followed at every read of
the description. `ai_lists.gate_list` lists roles by kind: chat roles as chat models, image roles with `image_out` and no
tools; `GATE_NOT_CHAT` is gone (a record from before keeps the old rule until the next read). OpenAI's image models are
its list for the images job. `images.make_image` is the one images call (OpenAI's format; a gate's path, a preset's
`images_path`, or `/images/generations`). The `images` capability (off by default) adds `make_image` (read), offered
only for a picture's words; the images job's card shows while it is installed. `ToolResult.image` reaches the channel's
`send_image` (Telegram `sendPhoto`, WhatsApp media upload); a channel without one gets the line and says so. With the
capability on, a join asks for the gate's image roles.

Windows and macOS: not tested yet.
