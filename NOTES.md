### לבעלים

- הסוכן עובד כמו קודם: אותם מודלים במחשב שלו, אותו חיפוש ברשת ואותו דף.
- עדכון של הסוכן רושם עכשיו גם גרסה חדשה של שירות החיפוש ושל המודלים שלידו.
- הגרסה החדשה נכנסת לפעולה כשהשירות מופעל מחדש.
- כשהחיבור של הסוכן מופעל מחדש, שירות המודלים שלידו חוזר אליו לבד, עם הכרטיס.

### Technical

Issue 72, item 1, stage 3 (a service beside the agent): a capability's service is declared once, in its manifest's
`service:` block (image pinned by digest, memory limit, port, `network: sidecar`, `gpu: when_present`, a named volume,
a config file from a template in the capability's folder, a health check), read strictly by `capabilities/services.py`
and listed by `capabilities.services()`. The keeper loops over the declared services everywhere it named Ollama and the
web search: the compose renderer (`keeper/compose_services.py`), `compose_engine`, the store (`AgentEntry.services`,
stored in the same shape as before, so every record reads with no migration and an older keeper still reads it), the
container names (`updates.containers.service_name`), removal, the lifecycle and the jobs. `keeper/service_steps.py` is
the one service step (make, make everywhere, drop), replacing `ollama_steps.py` and `search_steps.py`; the Ollama card's
own jobs moved to `keeper/ollama_jobs.py`. The manifests' keeper action is `service` and their revoke `service`; step
ids are unchanged. An update now pins each service's image and memory limit in the agent's compose file from the
manifest (`compose.pin_services`), so a new SearXNG or Ollama image reaches existing agents when the service is next
made. Every service in the sidecar's network follows it in the lifecycle (the Ollama too, its card kept: `DeviceRequests`
joins `HOST_KEYS`). One compose line changes form: `OLLAMA_HOST` is now quoted like every other value. The rendered
compose files, the Engine API create bodies, the search's settings and the stored records are byte-equal to 1.30.3 for
32 agent shapes but for that line (`scripts/compose_equivalence.py`), and the page is unchanged (the snapshot,
`differing 0`). `test_the_keeper_names_no_service` keeps the keeper's generic code free of any service's name.

Windows and macOS: not tested yet.
