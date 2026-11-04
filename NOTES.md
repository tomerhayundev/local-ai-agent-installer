### לבעלים

- הודעות קוליות עוברות עכשיו דרך שער הבית, ולא דרך שירות תמלול נפרד: ההתקנה כבר לא מבקשת כתובת.
- בחיבורים יש כרטיס "תמלול הודעות קוליות". כשהשיחה רצה על המודל של הבית, הוא מתמלל בלי לבחור כלום.
- אפשר לבחור שם גם מודל תמלול של שירות אחר.
- כשהשער עמוס הסוכן מחכה בתור, וכשמשהו לא מצליח הוא אומר בצ'אט מה קרה.

### Technical

Voice notes go through the gate, the one way to call it (house R7/R8, step 9; #22). The Whisper-over-Wyoming path
is gone: `WHISPER_HOST`/`WHISPER_PORT`, the page's address form and its check, the keeper's `whisper_address` cleanup
and the `wyoming` package; the agent drops a saved address at start. `voice.py` is the one call: OpenAI's
`POST /audio/transcriptions` form (`file` as the channel gave it, typed by its first bytes, with its `Content-Length`;
`model`; the profile's `language`; `response_format: json`) on the gate's own path from the description, or after any
other service's url. The transcribe job (`ai_jobs`, the `transcribe` fact) is drawn while `voice_messages` is
installed; its picker lists the roles `/gate/connect`'s `audio.transcriptions.roles` names (`gate._audio`; the record
keeps `transcribe_roles` with a role that picks first, so Home AI leads, and `transcribe_path`, `_wait`, `_max`), and
any service's speech-to-text models by their id (`ai_lists._transcribers`; none at an Ollama). The join asks for those
roles by the audio block, never by name, and the gate models' saved facts carry `transcribe`, so "as the chat"
transcribes through Home AI. A model chosen for the job is checked by half a second of silence through the same call
(`voice.check`), never a chat. Busy means wait: a `202` the gate queued, or a `429`/`503` with `Retry-After`, is asked
again with the same `X-Request-Id` until the gate's line (600 s) and its own `wait_seconds` are up; only then is it
`waiting`. No `X-Gate-Priority` is sent (someone waits for a note). Each failure is a kind said in the agent's words
(`words/voice.py`). The description's `up` is not a gate on the call: a stale read would refuse what the gate takes,
and the call's own answer says why. Spoken answers are #66.

Windows and macOS: not tested yet.
