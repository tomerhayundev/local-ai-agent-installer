### לבעלים

- חלקים ארוכים בדף נפתחים בלחיצה, ורק מה שמחכה לך פתוח.
- קישור מהצ'אט מגיע ישר לפריט הנכון, ואומר למה הגעת אליו.
- אפשר להתקין יכולת או שירות באותו מקום, בלי לעבור לדף אחר.
- הקשר בין סוכנים נקבע בשאלה אחת, במילים פשוטות.
- הסיכום היומי יכול להיות כבוי, ו"מה חדש" כתוב בעברית.

### Technical

Round 2 of the owner's page (#36). Update the keeper first: protocol 4. The keeper's version answer now carries
`checking_until` and `last_update`, which settings › updates reads for its four states (ready, updating, running and
being checked until a time, went back); a rollback no longer keeps the time of a check it stopped.
- **Folds (#31).** Every place is a list of rows (`page_shell.fold`): icon, name, state. One rule opens a row that
  waits for the owner, failed or is in progress; never a fold inside a fold. One title a screen; no intro paragraphs;
  one caption, "הסוכן יתחיל מחדש לרגע", beside a save that restarts the agent; the live chip is a dot.
- **Arriving (#34).** Every link between places is built by `page_places.link` with `open=`, `for=` and `back=`; the
  destination opens and marks the item and draws one line from a closed table with the way back. Google and Home
  Assistant are installed inside their row in חיבורים with the store's own confirm and job; the restart returns there.
- **Relationships (#35).** One question per other agent, four cards, a confirm with a before and after picture. A
  change is one keeper job (`POST /agents/{id}/links/change`) that drops the old links, makes the new one, and puts the
  old ones back if it fails. Each agent's own icon on the map and the cards. The chat uses the same words.
- **The daily summary (#33).** "כבוי" or "כל יום"; the profile keeps the last time in `daily_summary_last`.
- **Notes (#32).** Each release's entry starts with `### לבעלים`; the page shows only that part.
- `tests/test_page_words.py` counts the words a phone shows per screen and fails when one grows.

Windows and macOS: not tested yet.
