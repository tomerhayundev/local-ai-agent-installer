### לבעלים

- הסוכן והדף עובדים כמו קודם: אותן יכולות, אותן הגדרות ואותם מסכים.
- מה שכל יכולת מראה בדף שלה כתוב עכשיו במקום אחד, כך שקל יותר להוסיף יכולות חדשות.

### Technical

Issue 72, item 1, stage 5 (the page card), the last stage of the item: what a capability's page shows of its own is
declared once, in its manifest's `page:` block, read strictly by `capabilities/page_card.py`, and `page_section` and
`PAGE_SECTIONS` are gone. A `card` is declared fields (a name, a kind from a closed list: `text` or `secret`, its words
named in `words/capabilities.py`, its reader, `optional`, and for a secret the field it is kept for), the live check
before saving, the line above the fields and what a failed check says; the one shared card (`pages/capabilities/
needs.py`) draws and reads every card, replacing the per-capability `FORMS`, `OPTIONAL`, `SETTINGS_ONLY`,
`NEEDS_ABOUT` and `CHECK_FAILED` tables and the check's branch. A capability whose settings are its own names its view
from a closed registry (`levels`, `google`, `phones`, `tasks`: `routes.SETTINGS_VIEWS`; the phone's voice-key wait is
`routes.OWN_WAITS`), replacing the branches by name in `routes.py`. `from` (the rows elsewhere an install may be asked
from), `elsewhere` and `platform_why` replace `state.py`'s `FROMS`, `ELSEWHERE` and `PLATFORM_WHY`. The page is
unchanged (the snapshot, `differing 0`), as is what the model sees (`scripts/tool_equivalence.py`, byte-equal).
`test_the_capabilities_page_names_no_capability` keeps the page's generic modules free of any capability's name.

Windows and macOS: not tested yet.
