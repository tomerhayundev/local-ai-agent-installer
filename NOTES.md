### לבעלים

- כשמחוברים גם טלגרם וגם וואטסאפ, מה שהסוכן שולח בלי שביקשו הולך קודם לטלגרם.
- זה כולל תזכורות, מיילים חדשים והסיכום היומי.
- וואטסאפ מקבל אותן רק כשהחלון שלו פתוח, או כשהוא הערוץ היחיד.
- סוכן עם ערוץ אחד ממשיך בדיוק כמו קודם.

### Technical

#70 step 2b (owner decision 5). The ledger sends every row through `Messenger.notify_unasked`, whose order
(`unasked_order`) puts a channel with no window (`deadline` None) first, then one whose window is open, and a channel
that would need its template only last, when none ahead of it took the item, so nothing is lost while Telegram is
broken. The evening summary decides "send early" from `unasked_deadline`. One channel: as before. Notices not on the
ledger yet keep the main channel's order.

Windows and macOS: not tested yet.
