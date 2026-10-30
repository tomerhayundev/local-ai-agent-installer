### לבעלים

- בחיבורים, מתחת למודל של כל עבודה: כמה לחשוב לפני שעונים. בלי חשיבה, עם חשיבה, או לפי המודל.
- הבחירה מופיעה רק כשהמודל יכול לחשוב: בשער הבית, בשירות בענן או במודל בבית.
- הבחירה עובדת מיד, בלי הפעלה מחדש. עם חשיבה התשובות איטיות יותר, והסוכן מחכה להן יותר זמן.
- מה שהמודל חשב לא מגיע אליכם, רק התשובה.

### Technical

#51. `ai_thinking.py` says what a job's model offers (off, on or low/medium/high; the model's own default first when
nothing is sent by default) and what each service is sent: the gate `reasoning_effort` (`none`, `medium` for on, a
level), OpenAI `reasoning_effort` (levels only: its reasoning models always think), OpenRouter `reasoning`
(`{"enabled": false}` or an effort), Ollama Cloud `reasoning_effort` (its `/v1` ignores `think`, checked live), and a
home model through its fit (`model_fit.resolve(thinking=)`: Ollama `reasoning_effort`, llama-server
`chat_template_kwargs.enable_thinking`). Can-think comes from the gate's roles in `GET /gate/connect` (`thinking`,
`thinking_levels`, `thinking_default`, kept in the joined gate's record and read again with the heartbeat's
description), the lists (OpenRouter `supported_parameters`, Ollama `thinking` capability, OpenAI's reasoning ids:
a new slim fact `thinking`), and detection (llama-server's template takes `enable_thinking`). The choice is saved per
job with the model it was made for (`AISetup.thinking`) and switched in place (`ServiceManager.set_thinking`,
`POST /connect/ai/thinking`). `Brain` sends `thinking_fields`, waits `THINKING_TIMEOUT` for a request that may think,
and logs only the length of the reply's `reasoning_content`, `reasoning` or `thinking` and the gate's
`X-Gate-Thinking`; `from_wire` never kept them.

Windows and macOS: not tested yet.
