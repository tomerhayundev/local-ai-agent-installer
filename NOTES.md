### לבעלים

- שיחה בטלפון נפתחת עכשיו במשפט אחד: פתיחה, השם של מי שמקבל, מי מתקשר ומה רוצים.
- בדף, ב"איך השיחה נפתחת" מתחת לקול: הפתיחה ומי מתקשר, במילים שלכם, עם דוגמה איך זה נשמע.
- השם והבקשה נכנסים לבד לפי מה שביקשתם, וכל השורה מופיעה בכרטיס לפני ה-✅.
- הקול לא חוזר על ההצגה, ושואל שוב כשלא הבין תשובה, במקום לסיים את השיחה.

### Technical

#27. The brief carries the whole first line (`Brief.opening`, required, at most `OPENING_MAX`), which the runner says
word for word (`force_message`); `phone_line/prompt.opening_line` is gone. `place_call` takes `name` and `request`
(required); `phone_prefs.opening_line` joins the greeting,
the name, who is calling (`introduce_for`: the page's, or the default by the voice's gender) and the request. The page
keeps the two parts as phone choices (`PhoneSettings.greeting`, `.introduce`; `POST /connect/phone/opening`). "להתקשר
שוב" carries the approved line as `opening`. The voice prompt quotes the line as already said, forbids saying it or
introducing itself again, and asks again on an unclear answer. A line and an agent must both be on 1.11.0: the line
refuses a brief without an opening.

Windows and macOS: not tested yet.
