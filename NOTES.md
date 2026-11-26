### לבעלים

- מספר שאישרתם בזיכרון נחשב כמספר שכתבתם, אצל הסוכנים שלכם בלבד: השיחה יוצאת בלי לכתוב אותו שוב.
- כשסוכן שלכם צריך פרט שחסר לו, הסוכן הראשי עונה לו קודם ממה שהוא יודע, והבקשה ממשיכה בלי לשאול אתכם.
- רק כשאף אחד בבית לא יודע, אתם נשאלים פעם אחת, ותשובה שלכם ממשיכה את הבקשה לבד.
- מספר שנשמר לפני הגרסה הזאת יישאל עוד פעם אחת, ומאז ייחשב.
- קו טלפון שהוגדר קודם יראה "צריך הגדרה" פעם אחת: הגדרה מחדש מתקנת שמע שלא נפתח במחשב בלי מסך.

### Technical

Issue 72, item 5's real call: the main agent resolves a missing detail itself (design
`docs/superpowers/specs/2026-11-24-agents-resolve-missing-details-design.md`). `memories.by_owner` (a `COLUMNS`
entry, default 0) is decided at the one save, `_run_memory`, by evidence: a ✅ on a card drafted with nothing from
outside the house (the draft's `outside`; a card without the key saves 0), or, with no ✅, every number in the fact
is one the owner wrote in a turn of the owner group; an old row the owner says again with its number is raised to 1.
`tools/phone.py`: `approved_numbers`, read only through the R29-gated `_memories()` and only with memory on, count in
the one guard `_owner_wrote_number`; in an agent turn its two refusals tell the model to ask the asker for the
number, which must come from that asker's owner (`number_missing`, `number_not_owners`). `tools/agents.py` `_numbers_sent`:
an ask to an agent of the owner group adds the approved numbers its text holds, last, so the cap keeps them; an ask to
another owner's agent sends only the numbers in the owner's own words and is refused when it holds an approved
number (or, in an agent turn, one that came beside the task) they did not write. The agent list marks the owner's own
agents (`ASK_OWN_GROUP`), and the prompts (`ask_agent`, `ASK_CONTEXT`, the system prompt's `RESUME_RULE`, said only
while an asked agent's answer is in the history) tell the main agent to send what it knows to them and to ask again in the same turn. `phone-line.sh`
writes `monitor.bluez.seat-monitoring = disabled` in its WirePlumber drop-in and `status` checks for it. Evaluation:
cases 144-147 (the harness records what each task carried, keeps an asked agent's result in a case's history, and
can mark an agent as another owner's).

Option C, an agent's question is an open request that code holds (design
`docs/superpowers/specs/2026-11-25-agents-hold-an-open-question-design.md`). The asked side: a refusal names what is
missing (`ToolError.missing`, one of `tools.base.MISSING`; `place_call`'s number refusals say `number`), and
`ask_back`, the link's second tool, offered only in an agent turn that is no edit turn, marks `text` and ends the turn;
`LinkChannel.reply` sends such an answer as status `asks` while no call of the turn succeeded and there is no card
(the code's fallback is never the question: `ASKS_NUMBER`). The asker: `_result` gives an `asks` of the owner group
(this owner's own task, sent `mine`, its agent still in the group, nothing from outside, under `QUESTION_ROUNDS_MAX`)
to the main agent's short call (`agent/questions.py`: one model call with one tool, before the turn lock), which reads
inside `Tools.question_scope` (the turn's state set by code from the first task's outbox row). An answer closes the
task and owes its follow-up in one transaction (`link_tasks.follow_up`), then sends it through the one ask
(`Tools._send_ask`; the answer's phone numbers must go beside it); no answer: the question is told and held open on
the row (`missing`, `question`, `asked_until`, one per agent, blanked when it closes). The owner's message resumes
it: one phone number by code, anything else through the turn with a code-written line per open question (no shortcut
while one is open). A follow-up a stop left owed goes once at the start (`Delegator.send_owed`). Moved:
`tools/numbers.py` (`numbers_in`, `approved_numbers`, `dialable_in`), `phone_numbers.py` (`normalize_number`, from
`phone_line/brief.py`) and `words/link_prompts.py` (the link's prompt words). The short call's answer counts only when
the house holds it (`agent/questions.held`: a number question only by a phone number, a text answer only when half
its words are the memories' or the owner's recent messages'). `ASK_CONTEXT` is one short line again. Evaluation: case
146 replaced, cases 148-150 (`eval/asks.py`), and held-out h92 moved to the tuning set as 151.

Windows and macOS: not tested yet.
