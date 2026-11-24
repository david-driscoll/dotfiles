# MCP gateway baseline

This optional Compose baseline runs Docker's MCP Gateway; it does not change
existing MCP registrations or start anything during dotfiles setup. Catalog
servers are launched dynamically by the gateway, not as Compose services.
Neo4j and its existing volumes are outside this baseline.

## Machine-local setup

Install Docker with Compose 2.20.0 or later. Docker Desktop on Windows or
macOS, or a Linux Docker Engine, must provide the Docker API socket at
`/var/run/docker.sock` to the container. A rootless or custom Docker context
may require a machine-local socket override. The socket grants broad Docker
control, effectively host-administrator access in many configurations; use
this only on a trusted daemon and with trusted catalog servers.

Create a separate, untracked Compose file on each machine. For example, if
the machine directory and this dotfiles checkout are siblings:

```yaml
include:
  - ../dotfiles/mcp/compose.yaml
```

Compose resolves the include path relative to the machine file, and paths
inside an included Compose file relative to that included file. Adjust the
path for the actual checkout; on Windows use a valid absolute path or a
relative path when appropriate. Keep machine files, credentials, and local
overrides outside the repository. Compose `include` imports distinct
resources; it does not merge same-named services. Use Compose overrides or
separate projects for customization, not duplicate included service names.

Set `MCP_GATEWAY_SERVERS` to a nonempty comma-separated list of **only**
the Docker catalog server names approved for that machine. There is no
default selection. Set `MCP_GATEWAY_AUTH_TOKEN` to a nonempty, high-entropy
secret before running Compose. The baseline passes only that explicitly
declared environment variable into the gateway. Do not put secret values in
tracked files, commands, shell history, screenshots, or logs.

Use the existing fnox providers and profiles: age-encrypted values for
shared secrets, and the existing machine-local provider for local secrets.
Keep age private keys outside git. Provision and unlock the chosen provider
separately; do not create keys or store plaintext defaults as part of this
setup. Use a narrowly scoped fnox profile to inject the gateway token into
the Compose process. `fnox exec` affects its child process; it does not
automatically configure clients or authenticate catalog servers. Verify
provider availability and required values without displaying them. Gateway
environment values remain inspectable by Docker administrators and are
retained in container configuration for restart.

From the machine directory, with those two variables available:

```sh
docker compose config --no-interpolate --quiet
docker compose up -d
```

The first command validates structure without resolving variables; `up`
also checks that both required variables are set. Do not use plain
`docker compose config` with live secrets: it can print them.
The gateway restarts when Docker restarts, unless explicitly stopped. Docker
Desktop starting at sign-in is a separate machine-level setting. Updating a
secret or selection requires recreating the gateway with Compose; restarting
Docker alone retains the previous container configuration.

The endpoint is `http://127.0.0.1:8932/mcp` using Streamable HTTP and
`Authorization: Bearer <token>`. Loopback limits network exposure but is not
authorization; verify that the deployed gateway rejects an unauthenticated
request and accepts the intended client before using it. Other local users
may be able to reach the port. Protect client configuration containing the
token and never place it in this repository. Port 8932 is distinct from the
existing pilot. For another conflict, use a second machine-local Compose file
with `-f` and replace the `gateway` ports with `!override`, keeping the host
binding on loopback. `!override` requires Compose 2.24.4 or later. Specify
both `-f` files for all lifecycle commands; do not redefine `gateway` directly
in the including file.

## Selection, secrets, and clients

The gateway's `--servers` selection applies to **all** clients of that
gateway. A client-side tool filter is not a security boundary. Do not share
one gateway across clients with different privileges and claim isolation.
Use separately configured gateway instances, project names, loopback ports,
tokens and server selections for different trust levels; test enforcement
before switching clients. Docker's `--tools` option can further restrict a
gateway, but its exact behavior and interactions with dynamic tools must be
verified on the deployed version. A shared Docker socket is not a hard
security boundary between mutually untrusted instances.

Keep Aspire, the Playwright browser-extension integration, mise, and other
host-dependent tools native unless an equivalent is verified. Keep remote
OAuth services direct until gateway authentication is verified. Gateway
server secrets and OAuth require a separately verified provider/injection
setup; the gateway token is not automatically forwarded to catalog servers.
Preserve existing registrations until each replacement's tools and behavior
have been checked; similarly named servers can be different implementations.

## Updates and rollback

The baseline requests `docker/mcp-gateway:latest` on each `compose up`,
not on every daemon restart. The `latest` tag has not been verified to be
the newest stable release; a newer release may be a pre-release. No client
cutover has been verified. A mutable tag can change behavior or break
authentication, tool filters, or compatibility; review release provenance
and re-test before adopting an update. This baseline does not verify the
gateway image's signature. `--verify-signatures=true` retains Docker's
catalog-image verification: Docker MCP images in the `mcp/` namespace must
be digest-referenced and verified by the gateway. It is not a signature
guarantee for arbitrary third-party images. Do not disable verification to
make an unverified server work.

Run `docker compose down` from the machine directory to stop and remove only
that Compose project. Remove its client registration separately if one was
added; existing direct registrations and the pilot are otherwise unchanged.
Do not delete volumes or the unrelated Neo4j deployment. If an update fails,
restore a previously reviewed gateway image through a machine-local override
and re-test before reconnecting clients.

References: [Compose include](https://docs.docker.com/compose/how-tos/multiple-compose-files/include/),
[Docker MCP Gateway](https://github.com/docker/mcp-gateway),
[gateway security](https://github.com/docker/mcp-gateway/blob/main/docs/security.md),
and [fnox providers](https://fnox.jdx.dev/providers/overview).
