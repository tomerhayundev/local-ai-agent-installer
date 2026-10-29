### לבעלים

- כשהדף נפתח בתוך הדפדפן של טלגרם, מופיע למעלה "לפתוח בדפדפן". לחיצה פותחת את הדף בדפדפן של הטלפון, כבר מחובר.
- אם הדפדפן לא נפתח, אפשר להעתיק את הקישור ולהדביק אותו בדפדפן.

### Technical

#45: a way out of Telegram's in-app browser. Every signed-in screen draws `page_shell.in_app_offer` hidden
(`data-in-app`); `live.js` shows it only where Telegram's browser put `TelegramWebview` (Android) or
`TelegramWebviewProxy` (iPhone) on the window, since its User-Agent is the system's own. Its form posts to
`/connect/devices/browser` (`page_access.py`), which answers a screen with the `device` sign-in link (the same code as
"להוסיף מכשיר" while it is good: the phone's browser has no session of the app's) as `page_shell.browser_link`:
`intent://…#Intent;scheme=https;end` on Android, `x-safari-https://…` on an iPhone (iOS 17 and later), the plain link
beside the page anywhere else, with until when it is good and the link to copy. `page_asserts.left_in_place` lets
these two schemes stay without a new tab (the app is left, its browser stays). Not tried on a phone yet: the test plan
is on #45.

Windows and macOS: not tested yet.
