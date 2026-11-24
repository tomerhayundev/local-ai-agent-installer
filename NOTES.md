### לבעלים

- שינוי פנימי, בלי שינוי בדף: מה ששונה בין השירותים שהמודלים באים מהם מתואר עכשיו בהגדרות של כל שירות.
- השירותים, המודלים, החשיבה והתגים של המחיר עובדים כמו קודם.

### Technical

Issue 72, item 5, stage 3: what differs between AI services is declared. Each block of `ai_presets.yaml` names its
ways: `thinking` (levels, always, and the request form, one of `ai_thinking.THINKING_ASKS`: `effort`, `reasoning`),
`models` (the list reader, one of `ai_lists.LIST_SHAPES`: `ids`, `rich`, `tags`; whether it is public; the query each
job filter asks; an `ids` list's patterns for chat, thinking and image models), `audio` and `tier`. The agent's own
Ollama is the ollama capability's (`ai_service:` in its manifest: its tag `ollama_agent`, label, sign-in page,
`cloud_stubs`), found by `capabilities.added_service`; the preset list stays three. One parser, `ai_ways.parse_ways`
(a new module both read), and one lookup, `ai_service.ways_of`; `load_presets` is read once per process.
`ai_thinking.fields`, `offer`, `cloud_offer` and `off_fields` take the ways (`CLOUD` and the preset branches are gone;
the gate keeps its kind's), `ai_lists` reads every list by its shape (`CHAT_ID`, `REASONING_ID`, `IMAGE_ID`, `FILTERS`
moved to the YAML), `ai_models.cloud_stub` and `price_tier` take the ways at their nine call sites, and
`pages/ai/state.LOCAL` and `pages/ollama/state.LOCAL_PRESET` read the capability's declaration. The local Ollama's
sign-in check reads its declared sign-in page. Gone as dead or one-time: `words/connections.PRESET_HELP`,
`NEEDS_KEY`, `NO_KEY_NEEDED` (read nowhere) and `convert_old`'s `ollama_local` branch (for agents saved before
1.7.0). `PROVIDER_NAMED`: 1 name in 1 pin (20 in 10 before), the stated `("model_facts.py", "openai")`: the API kind
a home server speaks. `test_a_fake_provider_plugs_in_as_an_ai_preset` adds a service as one YAML block. Recorded
thinking offers and fields for every service and state, list requests and rows for every service and job filter,
price tags and labels match the old code exactly; the page snapshot, with a new cloud-stub preview state, shows no
difference.

Windows and macOS: not tested yet.
