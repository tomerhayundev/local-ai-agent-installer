A computer that installs its agents from its own local registry now sees new versions on the agent's page, and
"update now" works there. Before, the keeper looked for that registry inside its own container, where "localhost" is
the container itself, so every check failed and the page said it could not check for a new version. Now the keeper
looks for it at the computer's own address as Docker gives it to containers (`host.docker.internal`), and the
keeper's settings file maps that name on Linux too. On Linux, the computer has to serve that registry, read-only, to
the agents' network (`docs/testing-with-a-local-registry.md` says how). Nothing changes for a computer that installs
from the published package. Update the keeper first, with the installer's "update the keeper", so its settings file
gets the new line.

An agent whose image was deleted while it ran (its version's tag was built again, which left the old image without a
name) can be updated again. The keeper reads the defaults it needs from the image under the same name when that image
is the same version; before, the update stopped with "the image it runs could not be looked at".

Windows and macOS: not tested yet.
