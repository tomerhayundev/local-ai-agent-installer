### לבעלים

- כשאומרים לסוכן קוד או סיסמה, כמו "הקוד של השער זה 4590", הוא מציע לזכור אותם ולא מנסה להפעיל את השער.
- בקשה להפעיל משהו בבית, כמו "תפתח את השער", עובדת כמו קודם.

### Technical

Tuning case 57 (#19). A home word ("שער") picked the `home` topic alone, so the memory tools were never offered. `words/heard.STATED_VALUE` matches a stated value (זה/זו/הוא/היא or "is" before three digits or more); when `routing._topics` picks a topic and the message states one, it adds `MEMORY_GROUP` (remember, suggest_memory, forget) beside it. A setting such as "הטמפרטורה בסלון היא 25" and a message that names no topic are unchanged. Measured on the full matrix ×3 and on the second family: see `docs/tuning-log.md`.

Windows and macOS: not tested yet.
