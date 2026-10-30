### לבעלים

- מנהל הסוכנים מתעדכן קודם, ואיתו קו הטלפון, כדי שהשיחה תיפתח בפתיחה החדשה.
- אחר כך הסוכן מתעדכן כרגיל, בלילה או מ"לעדכן עכשיו".

### Technical

Keeper protocol 7 (`keeper/store/base.PROTOCOL`, `page_http.PROTOCOL`). The phone line follows the keeper's release
(`keeper/line.follow`), and 1.11.0's line is the one that speaks `Brief.opening`; with protocol 6 a 1.9.x keeper never
replaced itself, so agents on 1.11.0 would send briefs the old line could not speak. A keeper on 6 now replaces itself
(and moves the line) before an agent moves to 1.11.1, the way 1.7.1 did for the Ollama steps.

Windows and macOS: not tested yet.
