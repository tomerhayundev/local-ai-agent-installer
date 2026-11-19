### לבעלים

- הסרת סוכן עוצרת גם שינוי בקישורים שכבר רץ איתו, כך שלא נשאר קישור לסוכן שהוסר.
- שינוי שנעצר באמצע מחזיר את הקישורים שהיו לפניו.

### Technical

#65, from the security review of 1.15.3. `Jobs.cancel_all` (`keeper/jobs/runs.py`) now cancels every link job that
has not ended and `links_job.touches` the agent, running or waiting, not only a waiting one that names it. A link job
that has written already (`links_job.wrote`: its drop or mint ran) is not stopped before its next step, so its ends are
told what changed; a change cancelled after its drop makes no new link and puts back the links it dropped, ending
`cancelled` (`put_back_part` when one could not be made again). `ends_made` is kept for every link job in
`Jobs._begin`, not only one that waits; `Jobs.ends_moved` checks it at the turn check, before the mint (`no_agent`)
and before each put-back write, so no link is written to an agent removed or made again under its id since the job
began. `queue.link_ends` also names the ends of the links a job holds. Tests in `test_keeper_links_job.py`: a running
link cancelled by a removal, one that wrote ending as it would, a change cancelled after its drop putting back, and a
running link or a put-back never reaching an agent made again under its id.

Windows and macOS: not tested yet.
