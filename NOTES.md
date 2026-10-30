### לבעלים

- מנהל הסוכנים מתעדכן תמיד לפני הסוכנים, ואיתו קו הטלפון. סוכן לא רץ על גרסה חדשה ממנו.
- בעדכון הלילי מנהל הסוכנים מתעדכן קודם, והסוכנים באותו לילה, לא בלילה שאחריו.
- "לעדכן עכשיו" לגרסה שיצאה ממש עכשיו מעדכן קודם את מנהל הסוכנים, במקום להיכשל.

### Technical

The keeper is never older than an agent it runs. `self_update.needs_newer_keeper` is now "the release is newer than
this keeper's VERSION" (`version.newer_than_this`), not "its image's keeper protocol is above store.PROTOCOL", so no
release can forget a flag: 1.7.0 and 1.11.0 did, and their agents ran ahead of the keeper and of the phone line that
follows it. The update API looks up a version its stored list does not hold yet (`Registry.releases(fresh=True)`)
before choosing keeper-first; the updater refuses a version newer than itself before any pull. The 04:00 window that
replaces the keeper leaves the night open, so the new keeper moves the agents in the same hour; a swap that came back,
one not due yet, or a version in `keeper_failed` records the day, and one that could not start yet is tried at the
next look. Keeper protocol 8 is the last move made for an update: keepers before 1.12.0 still decide by it.

Windows and macOS: not tested yet.
