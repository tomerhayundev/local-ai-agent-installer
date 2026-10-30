### לבעלים

- חיבור לגוגל חוזר עכשיו מגוגל אל הדף, במקום דף שגיאה.
- סוכן שכבר יש לו לקוח גוגל: מוסיפים ללקוח בענן של גוגל את כתובת החזרה החדשה, ואז מתחברים שוב.

### Technical

Google's redirect is now `/connect/google/callback` (`pages/google/state.CALLBACK`). Tailscale serves only
`/connect` on the page's port (`keeper/tailscale.PAGE_PATH`), so `/google/callback` was answered by Tailscale's own
404 and the code never reached the agent. `test_the_callback_is_under_the_path_tailscale_serves` holds the two
together.

Windows and macOS: not tested yet.
