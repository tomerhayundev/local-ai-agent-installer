### לבעלים

- שום פעולה בדף כבר לא נדחית בגלל שמשהו אחר תפוס: היא נכנסת לתור, והדף מראה את המקום שלה בתור.
- זה כולל חיבור בין סוכנים כשחיבור אחר רץ, וטלפון שמוסיפים בזמן צימוד או כשסוכן אחר מוסר מהקו.
- עדכון, הפעלה מחדש והסרה שמחכים בתור לא הולכים לאיבוד גם כשמנהל הסוכנים מתחלף או מופעל מחדש.

### Technical

Every keeper action goes through one line (the house plan's "busy means wait in line, never a refusal"). Jobs._begin
picks the line for every job of every kind (`keeper/jobs/queue.py`): its agent's, the computer's link line (one link
job at a time) or the phone line's (`line_steps.line_waits`: a job that needs the line while another agent's removal
may take it down, or a phone added while a pairing runs); a waiting job keeps `line` and `queued`, the page gets its
`place`, and it goes on through `_begin` again when its line is free (link and phone rules asked again then; a waiting
job is not a phone user). The update, restart and removal routes write a waiting action to `keeper.yaml`'s `waiting`
(`Store.waiting`), the next keeper resumes it (`resume_waiting`), and the keeper's own replacement no longer refuses
them. The only `busy` left is an agent being removed: nothing waits on it. A waiting link job is bound to the
agents it links (`ends_made`): one removed or made again under its id ends it `no_agent`, and a removal cancels it.

Windows and macOS: not tested yet.
