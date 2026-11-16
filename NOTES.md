### לבעלים

- בהגדרות › התראות יש שלושה סוגים חדשים: חפיפה ביומן מחר, הזמנה שמחכה לתשובה, ומצב בבית שבחרת.
- כל אחד כבוי עד שבוחרים לו: מיד, בסיכום היומי, או רק ברשימה.
- את המצבים בבית (למשל דלת שנשארה פתוחה) בוחרים באותו מקום.
- סוכן קיים ממשיך בדיוק כמו קודם.

### Technical

#70 step 5. `watchers.py` adds three kinds found in code with no model call, each its own source on the ledger:
`calendar_clash` (two timed events tomorrow that overlap), `calendar_invite` (an invitation in the next 14 days whose
calendar owner has not answered: `gcal.waiting`) and `home_state` (an entity the owner chose, in the chosen state for
the chosen minutes, read from Home Assistant's state API: `Home.state`). A watch kind's ceiling defaults to `off`
(`agent_profile.ceiling_default`), so its watcher does not even look; `proactive.home` keeps the owner's watches. An
item no longer true when it would be sent is dismissed from the watcher's last read. The summary's digest lines take
an icon per kind.

Windows and macOS: not tested yet.
