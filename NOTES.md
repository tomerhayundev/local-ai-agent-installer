### לבעלים

- "מי עושה מה": כרטיס לכל עבודה, עם רשימה נפתחת של מודלים שנשמרת אחרי בדיקה קצרה.
- כמה שירותי בינה מלאכותית יחד, כל אחד עם בדיקת מפתח אמיתית ועם מה שהחשבון אומר.
- חיפוש בכל המודלים, עם תג: בבית, חינם, בתוכנית או מחיר. לפני מודל יקר הדף שואל פעם אחת.
- מודלים שרצים במחשב של הסוכן עצמו: מתקינים, מורידים, מתחברים ומסירים מהדף.
- סוכן מגרסה קודמת ממשיך עם אותו שירות ואותו מודל.

### Technical

The AI setup is services, models and a model per job (`ai_service.AISetup`, the `ai` entry of
`channel_secrets.json`); an older single choice is converted once at start. `ai_runtime.ServiceManager` keeps one
Brain per job (`ai_jobs.JOBS`), switched in place; only chat's model decides tools and history, and `.env`'s `LLM_*`
is no longer a service of the agent. Key checks per preset (`key_check` in `ai_presets.yaml`, `ai_keys.check_key`),
model lists read whole under a raw cap and cached a day (`ai_lists.py`), tags and search (`ai_models.py`). The page's
dropdowns are the design system's `.select` (`page_shell.select_field`), submitted by `live.js` on change, with a
button without scripts.

The `ollama` capability (off by default, Linux with host steps on): host verbs `gpu.status`, `gpu.setup_toolkit` and
`gpu.undo_toolkit` (`keeper/host/gpu.sh`, its record under `/var/lib/local-ai-agent`), an `ollama` service in the
agent's compose in the sidecar's network only (`OLLAMA_HOST=127.0.0.1:11434`, its own volume, the image pinned by
digest), keeper jobs of kind `ollama` (`POST /agents/{id}/ollama`: toolkit, undo_toolkit, restart) and the removal's
`drop_ollama`. The page's card (`pages/ollama/`, `ollama_local.py`) pulls models from the agent to its own Ollama, and
signs in to ollama.com per agent (a link drawn only when it is ollama.com's, `/api/me` polled for the session that
asked). `scripts/check_ai_services.py` checks the services live, by hand, never in CI.

Windows and macOS: not tested yet.
