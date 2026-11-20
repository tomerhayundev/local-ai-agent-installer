### לבעלים

- יכולת חדשה בחנות, "חיפוש ברשת": הסוכן מחפש, קורא את האתרים ועונה בקצרה עם קישורים למקורות.
- קישור ששולחים לסוכן נקרא ומסוכם. בלי מפתח ובלי חשבון: לסוכן יש שירות חיפוש משלו.
- את המודל שקורא את האתרים בוחרים בדף, בעבודת החיפוש ברשת.
- הגדרה מוכנה חדשה, "סוכן מחקר": חיפוש ברשת וזיכרון.
- מה שאתר כותב לא גורם לסוכן לעשות כלום, ולא נשמר בזיכרון בלי אישור.

### Technical

Specialist toolsets, release 2 (#19, #9, #16; design `docs/superpowers/specs/2026-11-19-specialist-toolsets-design.md`, "Release 2"). The stale branch `design/web-search` rebuilt on today's modules, its tests first. `web` is a capability (off by default): the keeper's `search_service` makes a SearXNG per agent (`keeper/search_steps.py`, pinned by digest, in the sidecar's network on `127.0.0.1:8888` only, its `settings.yml` read-only from `agents/<id>/search/`), and `drop_search` removes it. `web_search` and `read_page` (`tools/web.py`, both `read`, in `OUTSIDE_TOOLS`) fetch through `web.py` (public addresses only, redirects checked by hand, size, time and type limits; the query cleaned of addresses and long numbers); the material is read by the `web` job's model with no tools, and the code writes the reply with the sources' links (a link the reader wrote is dropped). The history keeps only a note (`ToolResult.kept`); a memory the owner did not ask for waits for ✅ for half an hour after a web answer, even in auto. The reader's caps are per tier (`web:` in `model_profiles.yaml`, `Brain.web_caps`; a cloud model reads the most). Routing: the web's own words only (`WITH_WORDS_ONLY`), the owner's own topics win, a device named beside a clear web word goes to the web, and in `open` fit the web tools still come only with web words or a link. `WEB_SEARCH_URL` is an optional address on the capability's page, checked live, read only while web is on. The `research` preset is `{web: true, memory: suggest}`. The cloud reader's buttons, `web_pending` and `LLM_LOCATION` of the branch are gone (the AI page's web job replaces them).

Windows and macOS: not tested yet.
