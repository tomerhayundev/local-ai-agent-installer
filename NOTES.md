### לבעלים

- המודל של הבית מוצע עכשיו גם ליצירת תמונות, ראשון ברשימה, כשהשער של הבית אומר שהוא יוצר תמונות.
- כשהשיחה רצה על המודל של הבית, יצירת תמונות עובדת דרכו בלי לבחור שום דבר.

### Technical

A gate role's kind is its own `via` (chat, audio, media, image); what makes images is the description's
`images.generations.roles` (house #225: every image role says `via` image, and home-ai is listed first for a client
with a house image role). The gate's record keeps them apart (`kinds`, and `image_roles` in the gate's order), and
`ai_lists.gate_list` makes one row per role: `tools` for a chat role, `image_out` for an image role, so home-ai is both
and comes first among the image makers; a record from before keeps its old reading until the next read. The saved
facts of the gate's models follow each read of the description (`gate_runtime._gate_facts`, at the join and in
`_keep_grant`), so the images job's "as the chat" makes pictures through home-ai, and stops when the gate stops listing
it. Needs the gate of house #225: before it, image-safe says `via` chat and would be offered for chat too.

Windows and macOS: not tested yet.
