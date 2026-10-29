### לבעלים

- בחיבורים רואים מיד מי עושה מה: לכל עבודה המודל שלה, מאיזה שירות, אם הוא עונה ומה הוא עולה.
- כדי להחליף מודל לוחצים עליו ובוחרים אחר, במסך משלו. אפשר גם לחפש בכל המודלים של השירותים המחוברים.
- לכל שירות כרטיס משלו: אילו עבודות הוא עושה, המודלים שלו, "+ מודל", "לבדוק" ו"להסיר את השירות".
- הוספת שירות והסרה שלו נפתחות במסך משלהן, וההסרה שואלת קודם.
- בטלפון שום כפתור כבר לא נמעך לאות אחת בשורה.

### Technical

#49. The AI section's job card draws its chosen model as one link (`page_rows.chosen_link`) to the job's choice, a
focused screen under `GET /connect/connections/ai/<job>` drawn as a subpage of the connections place
(`AIPart.subpage`, `pages/ai/view_screens.py`); `/ai/service/<id>` (a service's "+ מודל", no job), `/ai/new` (a new
service, `?add=` the open choice, `?job=` where its key ends) and `/ai/remove/<id>` (asked; refused while chat uses
it) are the others. A screen reads its lists after the session is known (`Places.render(prepare=)`), its view lives in
a context variable, and a search is a GET (`page_shell.get_form`). The one services card becomes a card per service
(`state.service_cards`: the shown jobs it does, its models with the job using each); `without_model` and removal
count only jobs whose capability is on (spec 11.6). A gate request is a card of its own and a joined gate's details sit
in its card's fold; the agent's own Ollama card is its service card. An answer that lands on the section is a 303 to
its card with its notice told once (`OwnerPage.tell`). `POST /connect/ai/change` and `/connect/ai/search` are gone.
Design system: rows with a trailing action never crush it (`.pick-row`, `.source-row`), and `.chosen`, `.option`,
`.add-box`, `.back-link`, `.count-fold`, `.service-head`, `.tag.is-job`, `.btn-danger-quiet`.

Windows and macOS: not tested yet.
