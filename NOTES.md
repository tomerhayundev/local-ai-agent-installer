### לבעלים

- הסוכן יכול לענות בהודעה קולית: על הודעה קולית, או על כל הודעה.
- כבוי עד שבוחרים בהגדרות › על הסוכן, תחת "תשובות בקול", כשהודעות קוליות מותקנות.
- הקול הוא של המודל שנבחר ב"הקראת תשובות" בחיבורים, ונבדק במשפט קצר.
- אישורים וכפתורים נשארים בכתב. כשמשהו לא מצליח, התשובה מגיעה בכתב עם הסיבה.

### Technical

#66. The owner's choice is `voice.answer` in `agent.yaml` (`off`, the default; `to_voice`; `always`), read by
`agent_profile` (`VOICE_ANSWERS`) and written by the keeper's settings job (`catalogue.SETTINGS`), from a form in
Settings › about drawn while voice messages are installed (`pages/settings/`, `read_voice`). No tool reaches it. The
speech job (`ai_jobs.JOBS["speech"]`, the `speech` fact) is drawn while it is on (`ai_jobs.spoken_on`, `SPOKEN`, handed
to the AI page as `AIPageDeps.switched`). Its list: the gate's roles `audio.speech` names (`gate_grant.made_of` keeps
`speech_roles`, Home AI first, `speech_path`, `speech_wait`; the join asks for them while it is on), and any service's
`tts-*` / `gpt-*-tts` models (`ai_lists.AUDIO_JOBS`); its check is a short sentence spoken (`speech.check`).
`speech.py` is the one call: `POST {base}/audio/speech` with `{model, input, response_format: opus}` (and OpenAI's
`voice` to a service that is not a gate), busy meaning wait with the same `X-Request-Id` as `voice.transcribe`; a
400/422 naming `response_format` is asked once more for mp3 (Hermes's fallback, `fe8b920cae`), and `voice_note` makes
Ogg Opus of anything else with ffmpeg. `spoken_text.py` strips what is for the eye and cuts at sentence ends under
`CHARS`, at most `PARTS` voice notes. `send_voice` joins the channel interface (Telegram `sendVoice`; WhatsApp an
uploaded `audio` with `voice: true`, the upload shared with `send_image` in `WhatsApp._upload`) and `Messenger`. The
agent speaks only the owner's own turn, an answer that is text alone with no address or code in it (`Agent._speaks`,
`spoken_text.for_the_eye`), after what was heard as text;
the history keeps the text, the audio is never kept, and every failure sends the text with
`words/voice.speech_problem`. Tests: `test_speech.py`, `test_spoken_answers.py`, the fake gate's speech endpoint, the
preview's `ai-spoken` state. No prompt, tool or routing changed, so no evaluation ran.

Windows and macOS: not tested yet.
