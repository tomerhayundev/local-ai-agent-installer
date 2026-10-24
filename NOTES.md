Approvals relayed through the main agent, and specialists with a chat of their own. The owner can ask the main agent
for a phone call, the phone agent drafts it, and the owner approves it in the main agent's chat. **Update the main
agent and the phone agent to 1.3.0 first** (an older release's profile reader rejects a specialist with channels or
with `capabilities.phone`, and the installer offers a main agent only from 1.3.0).
- **A call asked through the main agent.** The owner says "call the clinic and ask if they're open on Friday" to the
  main agent. Its model passes the task to the phone agent (`ask_specialist`); the phone agent drafts the call as it
  always did, and the exact card reaches the owner in the main agent's chat, word for word, under one line written by
  code that names the phone agent. The buttons are the main agent's own: ✅ להתקשר, ✏️ לשנות, ❌ לבטל. The main
  agent's model never sees the card, a number from it or the call's words, and cannot approve or change it: only the
  owner's tap makes the approval.
- **How the tap is checked.** The tap goes back to the phone agent as a signed `decision` bound to the draft's
  reference, its hash and the SHA-256 of the card the owner saw. The phone agent's code runs it once, only while the
  draft is still the same and in time (the kind's own expiry, measured from the moment of the tap), and answers in a
  line written by code. A tap that can't be delivered, or fails at the phone agent, opens the card again while it is
  in time; a different, older or already-handled card fails closed with a line saying so. A card too long to show whole
  is not shown at all: WhatsApp and Telegram never cut a message that has buttons, so the owner never taps ✅ under a
  text they did not see whole (a long one goes in full, with the buttons after it, or is refused).
- **✏️ changes a card.** The owner's next message in the main chat goes to the phone agent word for word as the change
  (not through the main agent's model), and the phone agent drafts a new card that replaces the old one. The last ✏️
  wins across the chat's drafts. Words written while a card waits, without ✏️, reach the main agent's model with a
  code-written hint that a request from the phone agent is waiting (its kind in words, never its content).
- **The call's notices and result.** "In the queue", "calling", the result with its [תמליל] and [להתקשר שוב] buttons
  and a lost call come back through the main agent to the owner in the main chat, each labelled with the phone agent's
  name. A notice is tried for 24 hours. [תמליל] is answered with the transcript in numbered parts, told in order with no
  model and never kept in the history; [להתקשר שוב] is answered by a new card to approve. A result the main agent never
  got (out of reach for a day) is told once in the phone agent's own chat, or kept for `call_status` for 7 days under
  "תוצאות של שיחות שלא הצלחתי למסור". One the main agent got but could not tell its owner in a day is still listed by
  `call_status` through the main agent for three days after the call ("שיחות שהסתיימו לאחרונה").
- **Two chats, one phone agent.** A specialist may now have channels of its own (`channels: [telegram]`, a connections
  page and, with a chat, a daily summary), and the phone agent keeps its chat. A call asked in its own chat is approved
  there, with buttons in that chat, exactly as before 1.3.0; a call asked through the main agent is approved only in
  the main agent's chat. Every turn carries its origin, set by code (`owner` or `master`); an `ap:` tap on a card of
  the other chat is refused ("את הבקשה הזאת מאשרים בצ'אט של הסוכן הראשי, משם היא הגיעה."), and the call's notices go back
  to the chat the request came from. The main agent's tasks are kept in the phone agent's history under their own role,
  marked as the main agent's task, and never count as the owner's words. `call_status` and `cancel_call` see only the
  calls of the chat they are asked in, so a cancel in one chat never stops the other's call. While the phone agent's
  own chat is disconnected, the notices of a call asked there wait for it (they never go to the main agent).
- **Only calls are relayed.** In a turn that came through the main agent, every action but `call` is blocked (the
  calendar, email and home actions stay with the agent that owns them), and the safe checks that let an action run
  without ✅ are never consulted.
- **The number guard.** The task carries the owner's current message (`owner_text`) and the phone numbers the owner
  wrote in their own messages of the last half hour (`owner_numbers`: digits only, at most 10, never their words).
  The phone agent's number guard reads both: a number the owner gave a few minutes ago counts, and a number that only
  the main agent's model wrote does not. No other guard reads the half hour.
- **`phone` for a specialist.** A specialist may now turn on `capabilities.phone` (with `reminders` and `memory`,
  the only capabilities a specialist may have). `_template/specialists/phone.yaml` deploys either on its own or as a
  specialist that also takes calls from a main agent.
- **Each agent keeps its own link keys.** The keys of an agent's links are kept in a private file in its own data
  folder (`data/links.json`, mode 600, never in the database, a log or the weekly backup email), so a keeper that is
  down at start-up doesn't cut an agent off from the agents it works with.
- **The installer.** "A phone agent" asks, when there is an agent that can serve as a main agent, whether the phone
  agent is on its own or also takes calls from one; "Let a phone agent take calls from another agent"
  (`attach-phone`) turns an existing phone agent into a specialist of another agent, keeping its id, its chat, its
  line key, its data and its call history (calls it already made are marked as the owner's own); "Make a specialist
  independent again" (`detach-specialist`) is the reverse, and the agent keeps everything it has. Both ask first,
  warn when a call is under way, restart the two agents and put everything back when a step fails.
- **Limits.** A `decision` or a `button` older than two minutes is refused; the main agent keeps three open cards per
  specialist; a card's checksum, its text and the buttons it relayed are forgotten 30 days after they close.
- **Evaluation.** The matrix has 35 new cases (calls through the main agent, and in the phone agent's own chat) and an
  `eval-phone-specialist` profile.

Windows and macOS: not tested yet.
