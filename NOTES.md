### לבעלים

- תמונה שהמודל של הבית מצייר בעצמו מגיעה עכשיו בצ'אט כתמונה, ולא כטקסט ארוך.
- התמונה לא נשמרת בהיסטוריה של השיחה, כך שהשיחה הבאה לא נעשית כבדה בגללה.

### Technical

A chat answer that carries the picture the model made itself (the gate's Home AI draws and answers with the picture
inline as a markdown `data:` address; an OpenRouter image model answers in `message.images`) gives it to the turn as
its picture: `pictures.py` takes it out of the text (`take_inline`, `from_parts`: only `data:image` addresses, decoded
under `PICTURE_MAX`, kept only when the first bytes are a picture's; a link elsewhere is never fetched), `brain.from_wire`
puts it in the message's `image`, and the turn sends it by the one picture path (`send_image` on every channel; a
channel without one gets the words and says so). The text kept, logged and sent never carries it, and `brain.to_wire`
strips one saved before (`strip_inline`), so a 3 MB message already in a history is not sent to the model again.
`images.py` takes its picture check from `pictures.mime_of` (one implementation). No text the `Messenger` sends
(a reply, its parts, a picture's caption, a notice) carries a `data:` address of any kind (`pictures.no_data`).

Windows and macOS: not tested yet.
