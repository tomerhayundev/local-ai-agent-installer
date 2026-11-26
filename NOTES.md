### לבעלים

- כשסוכן צריך מספר שיש בזיכרון אבל לא נשמר מכם, הסוכן הראשי אומר לכם את זה כששואל.
- תשובה שלכם עם המספר ממשיכה את הבקשה, ומאז הוא נחשב כשלכם.

### Technical

The owner-question path of option C (1.30.13) says why it asks, and an answer marks the saved line. In
`delegation/results.py` `_asks`, when a `number` question goes to the owner and the memory read in `question_scope`
holds a phone number the owner never gave (`tools/numbers.py` `unmarked_numbers`, read by
`MemoryTools.scope_unmarked_numbers`, none with memory off), the main agent tells `chat.NUMBER_NOT_MARKED` after the
question (`QuestionTurns.holds_unmarked`). The owner's number that resumes an open question by code
(`QuestionTurns.on_owner_message`) marks each saved line whose every number it holds (`MemoryTools.mark_owner_numbers`),
as saying the line again does (`_already_saved`). On the house, the first try on 1.30.13 asked again without saying why:
its one saved number predated `by_owner`. Tests: `tests/test_unmarked_number.py`.

Windows and macOS: not tested yet.
