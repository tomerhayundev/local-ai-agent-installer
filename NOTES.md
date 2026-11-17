### לבעלים

- כשהשירות שנבחר למיילים לא זמין, המייל נשלח מיד בלי מיון.
- מייל לא עובר אף פעם לשירות אחר במקום זה שנבחר למיילים.

### Technical

#39, from the security review of 1.24.0: `triage._tiers` took the chat's model as the first tier when the mail job's
was missing or not serving, so an email could reach a service the owner did not choose for mail. The first tier is
now the mail job's own or there are none; the email is announced unsorted, as before the router.

Windows and macOS: not tested yet.
