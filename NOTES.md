### לבעלים

- מנהל הסוכנים במחשב מתעדכן עכשיו לפני הסוכנים, כדי שהמודלים במחשב של הסוכן יעבדו.
- כשמנהל הסוכנים ישן מדי, הכרטיס אומר את זה ומתי הוא יתעדכן, במקום לומר שהוא לא ענה.

### Technical

1.7.0 added keeper parts (the `ollama` capability in the keeper's catalogue, `POST /agents/{id}/ollama`, the `gpu.*`
host verbs, the `ollama` job kind) but kept keeper protocol 4, so a 1.6.x keeper never replaced itself and agents ran
1.7.0 under it, where the Ollama card could not work. The keeper protocol is 5 (`keeper/store/base.PROTOCOL`,
`ollama_steps.KEEPER_PROTOCOL`): a keeper that speaks 4 replaces itself before an agent moves to 1.7.1 (at 04:00
once the release is three days old, or at once from "לעדכן עכשיו"). The page's own protocol follows it
(`page_http.PROTOCOL`, held equal to the keeper's), since an agent reaches 1.7.1 only after its keeper does. A keeper that answers without an `ollama` row is named
as too old on the card (`OLLAMA_WHY["old_keeper"]`), never as one that did not answer.

Windows and macOS: not tested yet.
