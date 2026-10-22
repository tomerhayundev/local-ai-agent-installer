Specialists. An agent can now have specialists: other agents, set up in advance with the installer ("A specialist of an
existing agent"), that do part of its work and answer it. The agent hands a task over with a new tool,
`ask_specialist`, and the owner gets the answer word for word (cut, with the cut stated, if it is longer than one
message), with the specialist's name on it. A specialist has no channel to people and cannot send, book or open
anything: it only answers its agent. Today a specialist can turn on only reminders and memory; web search is not part
of this change.
- Off by default. An agent uses its specialists only when its profile says `capabilities.specialists: true`; the
  installer offers to switch that on, and to restart the agent, when it makes a specialist for an agent that has
  it off (an agent on an older release is to be updated first: its profile would not load with that line).
- New profile fields for a specialist: `kind`, `parent` and `purpose` (see `_template/agent.yaml`). It may leave
  `channels` out, and only reminders and memory can be on.
- The keeper is now protocol 2: it keeps the specialist's record and introduces the two agents to each other. It
  replaces itself first on an update, as for any release that needs a newer keeper.
- The system evaluation knows `ask_specialist`: two new cases, and a made-up specialist for the agent that has the
  switch on.

The AI service is chosen on the agent's page: four presets (OpenAI, OpenRouter, Ollama Cloud, Ollama on this
computer), "Custom" by hand, or joining a house gate. The key is checked before it is saved, the agent switches at
once without a restart, and a gate that refuses the key stays stopped (even across a restart) until the owner
chooses again on the page. `.env`'s `LLM_*` stay as the server-set option, used only when the page has nothing
saved, and keep reaching their server through the environment's proxy settings as before; a service chosen on the
page never sends its key through a proxy from the environment. The installer's last screen says what comes next
on the page when `.env` has no `LLM_URL`.

Windows and macOS: not tested yet.
