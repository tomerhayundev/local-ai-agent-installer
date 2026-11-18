### לבעלים

- סוכן שרק סוכנים אחרים מדברים איתו לא צריך ערוץ משלו: בהגדרות › ערוצים מוצעים אפשר להוריד את כולם.
- אז הוא כבר לא מחכה לחיבור טלגרם, והסיכום היומי נכבה איתו (השעה נשמרת לפעם הבאה).

### Technical

`pages/settings/state.read_channels` saves an empty `channels` list instead of refusing it: `agent_profile` already
allows an agent with no channels (it hears only the agents linked to it), and `chat_attention` is empty for one. The
same write turns `daily_summary` off and keeps its time as `daily_summary_last`, since the profile refuses a summary
without a channel; the keeper's settings job already clears `primary_channel` and `private_channel` that are no
longer offered. Tests: `test_no_channel_leaves_an_agent_its_linked_agents_reach_and_its_summary_off`,
`test_no_channel_is_sent_with_the_summary_off`.

Windows and macOS: not tested yet.
