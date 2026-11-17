### לבעלים

- תדריך בוקר: מה ביומן היום, תזכורות להיום, ומה שחיכה לסיכום מהלילה.
- הוא נשלח עם ההודעה הראשונה שלך בבוקר, או בשעה שבחרת אם עוד לא כתבת.
- מפעילים ובוחרים שעה בהגדרות › התראות. סוכן חדש מקבל אותו מופעל.
- סוכן קיים ממשיך בדיוק כמו קודם.

### Technical

#70 step 6 (owner decision 4). `daily.morning_tick` builds today's brief in the evening summary's shape (the calendar
from now, today's reminders, "couldn't check", the digest items, the status line) as one ledger item per date
(`MorningSource`, `morning_sent`). It goes after the reply to the owner's first text or voice message at or after 05:00
(`Wiring.morning_asked`, from `owner_chat`), or at `proactive.morning` when a channel can send then (Telegram; WhatsApp
only inside its window); never 6 hours past that. Exempt from quiet hours and the cap. A digest item is logged only when
the agent has neither summary. The template gives a new agent `morning: "08:00"`; an existing agent has none.

Windows and macOS: not tested yet.
