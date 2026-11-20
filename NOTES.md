### לבעלים

- בזמן שמתקינים חיפוש ברשת, הדף כותב "הקמת שירות החיפוש ליד הסוכן", ולא שם של שירות אחר.
- גם בהסרה של חיפוש ברשת כתוב מה מוסר: שירות החיפוש וההגדרות שלו.

### Technical

The web capability's keeper step had the id `service`, which Ollama's step has too, and the page words a step by its id
(`STEP_WORDS`), so installing web showed "הקמת Ollama ליד הסוכן" (seen when web went on for a real agent after its
update to 1.29.0). Web's step is now `search`, with its own words, and the removal's `drop_search` has words too. A
test holds every step id to one step across the manifests, and every removal step to its words.

Windows and macOS: not tested yet.
