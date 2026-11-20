### לבעלים

- בכרטיס של החיפוש ברשת בדף, בוחרים מה הסוכן קורא: את העמודים עצמם, או רק את תקצירי החיפוש.
- עד שבוחרים, הוא קורא את העמודים, עם כל מודל. אפשר להחליף בכל רגע, והשינוי חל מהחיפוש הבא.

### Technical

The web job's reader no longer gets its amount from the model's size: a model of unknown size (a gate's `home-ai`)
counted as the small tier and read snippets only. What it reads is now the owner's choice on the web job's card
(`AISetup.reading`, saved under `ai.reading` only when it is not the default; `POST /connect/ai/reading`;
`ServiceManager.set_reading`), read at each search through `Tools.web_reading`: `pages` (8 snippets and 3 pages of
8000 characters, the default) or `snippets` (5 snippets, no page). `web.READ` holds the two; `web:` in
`model_profiles.yaml`, `Profile.web`, `web.web_caps`, `Brain.web_caps` and the cloud path's `CLOUD_CAPS` are gone.
The eval's reader reads the pages.

Windows and macOS: not tested yet.
