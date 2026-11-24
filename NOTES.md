### לבעלים

- שינוי פנימי, בלי שינוי בדף: כל חלקי הדף נרשמים עכשיו בדרך אחת.
- הדף, הצ'אטים והגדרות הטלפון עובדים כמו קודם.

### Technical

Issue 72, item 5, stage 4: one way to register a page part. `OwnerPage` takes one ordered `parts` sequence and builds
none itself: `wiring.page_parts(channels, ai=, phone=, given=)` builds the AI section, a part per chat channel, the
chats, the given parts and the phone's call settings last, in that one order, for `Wiring` and the tests' helper
alike; every part gets the page from one `Part.bind(page)` call. `OwnerPage`'s `ai` and `phone` arguments and its
`capabilities | {"phone"}` are gone; it takes `ai_source` (the manager's `source`, read by the top bar, the chats and
home's abilities row) and the `ChatsPart` (its channel routes come after every part's). `Wiring.phone_part` is what
`setup_known` asks. A part names the capability it belongs to (`PhoneSettings.capability`), the store finds it with
`own_part(name)` (the phone's page reads it that way), and an answer the keeper took is handed to every part's
`answered(kind, value)` hook, never keyed on the job's target (a preset's job raises the same ask), so the store no
longer saves a phone choice itself and no module reaches `page.phone_settings`. `NAMED` `("owner_page.py", "phone")`
1 → 0 and `owner_page.py`'s `IMPORTS` entry for `pages.phone.routes` is gone; no pin rose. The page snapshot shows no
difference. Item 5 is done, but for stage 2's real call on the house line.

Windows and macOS: not tested yet.
