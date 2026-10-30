### לבעלים

- עצרתם עדכון של כל העץ והתחלתם חדש מיד אחריו? סוכן משנה של בעלים אחר כבר לא נשמט ממנו.
- העדכון החדש שואל את הבעלים שלו שוב, כרגיל.

### Technical

#48 follow-up. A tree run's question to another owner that comes back `cancelled` (the run ended, or a new run of
the same main agent began while the request was sent) writes nothing (`TreeRuns._step`); before, its sub-agent was
written `cancelled` into the new run, which then skipped it.

Windows and macOS: not tested yet.
