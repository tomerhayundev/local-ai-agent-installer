### לבעלים

- הסוכן יודע לבדוק מה המצב בבית בלי לתת פקודה: "המזגן בסלון דולק?", "אילו מכשירים יש בבית?".
- ביומן: "מתי אני פנוי ביום שלישי?" עונה עם השעות הפנויות. "מה המייל של דנה?" אומר את הכתובת ששמרת.
- במייל: "תמצא את המייל מחברת החשמל" מחפש בתיבה, ואחר כך אפשר לבקש לסכם מייל מהרשימה או לענות לו.
- בטלפון: "מה אמרו בשיחה עם המוסך?" מספר מה היה בשיחות קודמות, עם התמליל בלחיצה.
- סוכן חדש מ"בית חכם" או מ"יומן ומייל" מגיע גם עם זיכרון, ו"יומן ומייל" גם עם תזכורות.

### Technical

Specialist toolsets, release 1 (#19; design `docs/superpowers/specs/2026-11-19-specialist-toolsets-design.md`). Every capability carries its full toolset, with no level to choose: `home_status` and `home_devices` (Home Assistant's `/api/states`, the device domains only), `find_free_time`, `find_contact`, `search_mail` and `read_mail`, `call_history`, all `read`. They come only with their own words (`routing.WITH_WORDS_ONLY`; the mail reads with a reading or finding word, `routing.mail_lookup`, never beside every email message), so every other message sees the tools it saw before. A mail a search finds is an `emails` row with status `found` (never announced, not counted as arrived; the mail watch turns it into an arrival if it arrives after); `read_mail` and the summary button share `mail_read.mail_summary`. Mail, addresses and the house's names are marked as outside text, and mail and addresses are blocked for another owner's agent (`PRIVATE_READS`). The house's chat words moved to `words/house.py`, the lookups' to `words/lookups.py`.

Windows and macOS: not tested yet.
