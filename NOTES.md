### לבעלים

- קישור כניסה כבר לא "נוצל" לפני שפתחתם אותו: פתיחה מראה כפתור "להיכנס", ורק הלחיצה מכניסה.
- כך קישור ששלחתם לעצמכם בצ'אט, או שהמצלמה הציגה, לא נשרף.
- כל קישור כניסה מכניס שני מכשירים: אפשר להעתיק אותו מהטלפון ולפתוח גם במחשב.

### Technical

A GET of a sign-in link (`/connect?code=`, `/connect/c/<code>`) uses nothing: without a session, a code still good gets
the go screen (`page_entry.go_screen`), whose one button posts it to `POST /connect` (`OwnerPage._go`), which redeems it
as the GET did. A browser with a session goes to `next` and the code stays good. On the owner's agents, the chat app's
preview of a copied link (no browser User-Agent: "מכשיר") had used each link seconds after it was shown. Sign-in codes
are good for `links.SIGN_IN_USES` (2) uses (`codes.uses`, a new column; other purposes stay at 1); `links.state` is
`live` while a use is left, and the add-device QR stays up after the first device (its live line says who came in) and
reloads once the link is used up. `post_form(csrf=None)` draws a form with no session token (the go screen's).

Windows and macOS: not tested yet.
