### לבעלים

- שינוי פנימי, בלי שינוי בדף: כל שירות קול של קו הטלפון מתואר עכשיו במקום אחד משלו.
- השיחות עובדות כמו קודם, עם אותם שירותי קול ואותם קולות.

### Technical

Issue 72, item 5, stage 2: the phone line's voice providers are declarations. ElevenLabs and xAI are each
`phone_line/voices/<name>.yaml` beside its session's module (moved from `phone_line/voice_elevenlabs.py` and
`voice_xai.py`): its label, key link, default voice, session (`module:attr`), the options its session is handed with
their `line.env` names and defaults (the model names and addresses that were module constants: `MODEL`, `URL`, `API`,
`TTS_MODEL`, `DEFAULT_LLM`, `ASR_PROVIDERS`, `DEFAULT_ASR_PROVIDER`, `AGENT_NAME`), the line's limits it takes
(`max_seconds`), its key header, key check (and the answer's flags that refuse a key), voice lists (and xAI's fallback
voices) and gender lookup. `manifests.providers("voice")` parses them; `manifests.hook` resolves every kind's code (it
moved from `channels/`). `voice.py`'s `make_voice`, `check_key`, `list_voices` and `find_voice_gender` are one body each
over the record (`DEFAULT_VOICE`, `XAI_VOICES` and the if/elif blocks are gone); `LineSettings.voice_options` replaces
`elevenlabs_llm`, `elevenlabs_asr_provider` and `model`, read generically (a `one_of` option lowercased);
`brief.PROVIDERS`, `PROVIDER_LABELS`, the line's default provider and voice, `keeper/line.py`'s `DEFAULT_PROVIDER` and the
page's key links are the records'. `PROVIDER_NAMED`: 20 names in 10 pins over 6 modules (73 in 19 over 12 before): the
voices' names and hosts are at 0. `test_a_fake_provider_plugs_in_as_a_voice` declares a voice in two files and checks
its key, lists its voices, reads a gender and makes its session. Recorded requests (URL, the key's header, body) and
answers of the three calls for 14 cases per provider, each session's opening requests and messages, and the line's
settings for six `line.env` files match the old code; the page snapshot, with a new two-keys preview state, shows no
difference. Stage 2 is done only after a real call on the house line.

Windows and macOS: not tested yet.
