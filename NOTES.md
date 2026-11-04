### לבעלים

- הסוכן שולח תמונה רק לתפקיד שהשער אומר שהוא מקבל תמונות.
- שער שעוד לא אומר את זה עובד כמו קודם.

### Technical

Which gate roles see pictures is now the house's own word for it (home #244): each chat role in `/gate/connect`'s
`roles[]` has `takes`, what its models take beside text for this caller ("images", "audio", "video"; [] for text
only; a role that picks takes what its picks take), and a role sees when its `takes` lists "images" (`gate.TAKES`,
`gate.TAKES_IMAGES`). The placeholder flag of 1.17.0 (`sees_images`, which no gate sent) is gone. A gate that gives no
role a `takes` list is read as before: its `vision` sees (`gate.SEES_BEFORE`).

Windows and macOS: not tested yet.
