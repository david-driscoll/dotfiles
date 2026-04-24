# Patches for llm-graph-builder

These patches are applied automatically by `run.ps1 --start` (idempotent).

Base SHA: `61121df4c15716f67636a4fac2c96e909d374ada`

---

## Patch B — Override `uri` in `/connect` response with browser-accessible URI

**File:** `backend/score.py`

**Context:** The `/connect` endpoint (`async def connect`, line ~546) returns a `result`
dict. The `uri` field in the result defaults to whatever the client sent — which in our
skip-auth setup would be `bolt://neo4j:7687` (the Docker-internal address). The frontend
uses this URI to construct Neo4j Browser links, so we override it with the host-accessible
`bolt://localhost:7687`.

`os` is already imported at the top of `score.py`.

**After** `result['gcs_file_cache'] = gcs_cache`, insert one line:

```python
        result['elapsed_api_time'] = f'{elapsed_time:.2f}'
        result['gcs_file_cache'] = gcs_cache
        result['uri'] = os.environ.get('NEO4J_BROWSER_URI', credentials.uri)  # ← ADD
        return create_api_response('Success',data=result)
```

`NEO4J_BROWSER_URI` is set to `bolt://localhost:7687` in the backend env (written by `run.ps1`).

---

## Patch C — Fall back to env-vars for Neo4j credentials

**File:** `backend/src/entities/user_credential.py`

**Context:** When `VITE_SKIP_AUTH=true` the frontend skips the login dialog and sends no
`uri`/`userName`/`password` form fields. Without this patch every API call that depends on
`get_neo4j_credentials` receives `None` values and raises a 400 error.

**Two changes:**

1. Add `import os` (not present in the original) after the existing imports:

```python
import os                                            # ← ADD
from pydantic import BaseModel, Field, validator
from typing import Optional
from fastapi import Form, HTTPException
```

2. Replace the `return Neo4jCredentials(...)` in `get_neo4j_credentials` with env-var fallbacks:

```python
# BEFORE
    return Neo4jCredentials(
        uri=uri,
        userName=userName,
        password=password,
        database=database,
        email=email
    )

# AFTER
    return Neo4jCredentials(
        uri=uri or os.environ.get('NEO4J_URI'),
        userName=userName or os.environ.get('NEO4J_USERNAME'),
        password=password or os.environ.get('NEO4J_PASSWORD'),
        database=database or os.environ.get('NEO4J_DATABASE', 'neo4j'),
        email=email,
    )
```
