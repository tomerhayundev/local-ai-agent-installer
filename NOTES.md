### לבעלים

- סוכן של בעלים אחרים לא יכול לשאול את הסוכן מה המצב בבית, כמו שהוא לא יכול לקרוא את המיילים.
- סוכנים של אותם בעלים שואלים כמו קודם.

### Technical

`home_status` and `home_devices` join `PRIVATE_READS`: in an agent turn from outside the owner group they are blocked,
as the mail reads and `find_contact` are (the house's command was blocked there already). An automated security review
of the 1.28.0 push named it: a lock, a cover or who is home is the owner's to share.

Windows and macOS: not tested yet.
