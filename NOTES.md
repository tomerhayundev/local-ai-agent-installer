### לבעלים

- הודעה שנשלחה לסוכן בזמן שהוא מתעדכן או מופעל מחדש כבר לא הולכת לאיבוד: הוא עונה עליה כשהוא חוזר.
- הודעה שנקטעה באמצע הטיפול לא מטופלת פעמיים: הסוכן כותב שהיא לא טופלה עד הסוף, ואפשר לשלוח אותה שוב.

### Technical

An owner's message that is a turn (text, a recording) is kept in the database from the moment a channel hands it
over until its turn ended (`owner_inbox`, `db/owner_inbox.py`), whichever channel it came on: until now it waited
only in memory, after Telegram had stored its offset and WhatsApp had marked it seen, so a restart lost it for good.
At start-up `OwnerChat.resume` runs the messages that still waited, in order, before a channel hands over a new one;
one whose turn the stop cut off is never run twice, and one that waited longer than `REPLAY_WITHIN` is not run late:
the owner is told once (`MESSAGE_LOST`). It is the link inbox's rule (new, working, reported after a restart).
Telegram hands each update of a batch over in a task of its own, in order, so a later message of the batch is kept
while the first one's turn still runs. Issue 72, item 7.

Windows and macOS: not tested yet.
