### לבעלים

- שינוי פנימי, בלי שינוי בדף: כל ערוץ צ'אט מתואר עכשיו במקום אחד משלו.
- וואטסאפ וטלגרם עובדים כמו קודם, באותן מילים.

### Technical

Issue 72, item 5, stage 1: the chat channels are declarations, not branches. Each channel is `channels/<name>.yaml`
beside its module (`whatsapp.yaml` order 10, `telegram.yaml` order 20, and the agents' `link.yaml`, `owner: false`,
still built by `wiring.py`): its label, its word in the page's lines, its tile, third party, setup (`page` |
`server`), its own `.env` settings with their defaults and `when:` switches (WhatsApp's `WA_*`, `PRIVACY_CONTACT`,
`PUBLIC_URL`, `GRAPH_API_VERSION` default v26.0), the agent settings it needs (Telegram's `PAGE_URL`), its check, its
`build`, and what a removal leaves by hand. `manifests.providers(kind)` (`DECLARED`, `read(folder, layout)`) parses them
once into frozen records, refusing an unknown field, a YAML without its module, a `when:` that is no switch and every
other problem at once, naming the file; `channels.hook` only resolves a record's `module:attr`. Each channel is built
by its `build(ChannelContext)` and takes its facts from its record (`channels.base.Declared`). `settings.py` reads the
profile's channels' settings generically (`Settings.channel_settings`; WhatsApp's `settings_problems` holds the
`WA_ALLOWED` checks); `agent_profile.CHANNELS_READY`, `CHANNELS_LATER` and `THIRD_PARTY` are gone (a profile naming
`signal` or `web` now gets "unknown channel"); `wiring.py` builds the profile's channels in one loop (`Wiring.wa` is
gone); the page's `CHANNEL_WORDS` and `CHANNEL_NAMES`, the installer's first channel, its closing line and Wi-Fi notes,
and the removal's `LEFT_BY_HAND` read the records. `ignored` now lists `GRAPH_API_VERSION` when it is set while
WhatsApp is off. A new guard, `test_generic_code_names_no_provider` (`PROVIDER_NAMED`: identifiers split on `_` and
CamelCase, strings but docstrings, declared hosts), started at 163 names in 35 pins over 20 modules and is at 73 in 19
over 12: the channels' names (`whatsapp`, `telegram`, `wa`) are at 0. `test_a_fake_provider_plugs_in` declares,
builds and draws a channel from its own two files only. `NAMED`: 215 names in 56 files (216 before). Recorded
`settings.load`, profile and installer outputs match the old code but for the two lines named above, and the page
snapshot shows no difference.

Windows and macOS: not tested yet.
