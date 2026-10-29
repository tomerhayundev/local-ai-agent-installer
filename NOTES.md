### לבעלים

- כניסה, חיבור או דף של סוכן אחר נפתחים עכשיו בכרטיסייה חדשה, והדף של הסוכן נשאר פתוח מאחור.
- אחרי שמחברים חשבון צ'אט, הסוכן שולח שם קישור שמחזיר לדף, מחובר, כדי להמשיך מאיפה שהפסקת.

### Technical

#45: what leaves the page opens beside it. `page_shell.outside_link` is the one way the page links to another site,
an app or another agent's page (a new tab, `rel="noopener noreferrer"`); `handoff` and the step text use it, and so
do the AI services' key pages, Google's API pages, the ollama.com sign-in, the voice key page and the agents' map.
`post_form`, `post_button` and `fields_form` take `away=True` for a form whose answer leaves the page (Google's
consent, a new agent's Tailscale sign-in and its page, another agent's page). A chat account just connected gets
`OwnerPage.linked_reply` in that chat: a one-time link back to the connections place. Guards:
`test_what_leaves_the_page_opens_a_new_tab_through_the_shell_only` (a new tab only from the shell; redirects away
listed in `REDIRECTS_AWAY`) and `page_asserts.left_in_place` on every preview screen. Not done here: a way out of
Telegram's in-app browser ("לפתוח בדפדפן"), which needs a test on an Android phone and an iPhone first.

Windows and macOS: not tested yet.
