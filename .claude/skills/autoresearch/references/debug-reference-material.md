# Debug Reference Material

Domain-specific debugging checklists, tracing protocols, and investigation techniques. Referenced from `debug-workflow.md`.

## Domain-Specific Debugging

Different domains have predictable failure modes. Apply domain-specific reconnaissance before forming hypotheses.

### API Bugs

Common failure points: auth middleware order, content-type mismatch, serialization/deserialization, HTTP status code semantics.

**API debug checklist:**
- Does the route exist and match the HTTP method?
- Is auth middleware applied and in the correct order?
- Does the request body parse correctly (Content-Type header)?
- Are 4xx responses distinguishable from 5xx? Is error shape consistent?
- Are query parameters validated and typed correctly?

### Database Bugs

Common failure points: N+1 queries, missing transactions, constraint violations swallowed by ORM, timezone handling, NULL propagation.

**Database debug checklist:**
- Are all writes wrapped in transactions where atomicity is needed?
- Are NULL values handled at the DB and application layer?
- Is the query hitting an index? (check with `EXPLAIN`)
- Is connection pooling exhausted? (check connection count vs pool limit)
- Are timestamps stored as UTC? Converted correctly on read?

### Authentication / Authorization Bugs

Common failure points: token validation skipping algorithm check, expired token not rejected, privilege escalation from missing ownership check.

**Auth debug checklist:**
- Is the JWT `alg` field validated (prevent algorithm confusion attacks)?
- Is token expiry (`exp`) checked?
- Is authorization (ownership check) separate from authentication (identity check)?
- Are there privilege escalation paths (e.g., regular user accessing admin endpoint)?

### Async / Concurrency Bugs

Common failure points: race conditions on shared state, missing await causing partial execution, event loop blocking, deadlock.

**Async debug checklist:**
- Is every `async` function `await`ed at the call site?
- Are shared mutable state accesses synchronized (mutex, lock, atomic)?
- Is there a risk of deadlock (two locks acquired in different orders)?
- Are network/database calls inside async handlers non-blocking?

### Network / Integration Bugs

Common failure points: timeout misconfiguration, retry storm on transient failure, missing circuit breaker, charset encoding mismatch.

**Network debug checklist:**
- Are timeouts set on all outbound calls?
- Is retry logic bounded (exponential backoff with max retries)?
- Is response parsing resilient to unexpected fields?
- Are character encoding assumptions explicit (UTF-8 everywhere)?

## What NOT to Do — Debug Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| **Fix before understanding** | You'll fix symptoms, not causes. The bug comes back. |
| **Change multiple things at once** | Can't attribute improvement/regression to any single change. |
| **Ignore disproven hypotheses** | Not logging eliminations means repeating failed investigations. |
| **Assume instead of verify** | "It's probably X" without testing = confirmation bias. Run the experiment. |
| **Skip reproduction** | If you can't reproduce it, you can't verify the fix. |
| **Debug in production** | Never investigate with live data. Reproduce locally first. |
| **Tunnel vision on one file** | Bugs often span boundaries. Trace the full data flow. |
| **Trust error messages literally** | Error messages describe symptoms. Root cause is often 2-3 layers deeper. |
| **Give up after 3 tries** | Some bugs need 10+ hypotheses. Shift technique, don't stop. |
| **Blame the framework** | 95% of the time it's your code. Prove framework bug with minimal reproduction first. |

## Multi-File Bug Tracing

When a bug spans multiple files or services, standard single-file inspection fails. Use a structured cross-file trace.

**When to apply:**
- Stack trace crosses multiple files/modules
- Bug involves data transformation across service boundaries
- Fix in one file doesn't resolve the issue (symptom vs cause)

**Protocol:**
1. Start at the symptom (error output or failing assertion)
2. Trace backwards across file boundaries: identify the data/call flowing in
3. For each file in the trace, record: what goes in, what comes out, where it transforms
4. Identify the first file where the output diverges from the expected contract
5. That file owns the bug — even if it's not where the error surfaces

**Multi-file trace map format:**
```
file-a.ts → file-b.ts → file-c.ts → ERROR
  input: {...}  transform: {...}  output: WRONG
         ^first divergence = root cause lives here
```

**Across microservices:** Add network boundaries to the map. Include request/response payloads at each service boundary. A bug "in service B" often means service A sent malformed data.

## Performance Bug Investigation

Performance bugs are correctness bugs where the output is "too slow" rather than "wrong". Apply the same scientific method with profiling as the measurement tool.

**Profiling first, guessing second:**
- Profile before optimizing — the slow part is almost never where you think
- Identify the single hottest path (slow query, slow render, slow computation)
- Reproduce the slowness with a minimal benchmark before attempting a fix

**Performance issue patterns:**
| Symptom | Likely Cause | Investigation Method |
|---------|--------------|---------------------|
| Slow API response | N+1 database queries | Log SQL queries, count DB calls per request |
| Slow page render | Expensive recomputation on every render | Profiling (React DevTools, Chrome DevTools) |
| Slow background job | Missing index on query inside loop | `EXPLAIN ANALYZE` on repeated queries |
| Gradual memory growth | Memory leak (event listeners, unclosed connections) | Heap snapshots over time |
| Slow cold start | Over-importing, large bundle, slow init code | Bundle analyzer, startup profiling |
| Intermittent slow requests | Lock contention or connection pool exhaustion | DB slow query log, connection pool metrics |

**Performance debug checklist:**
1. Measure baseline (p50, p95, p99 latency or total time)
2. Profile to find the actual hotspot (not the assumed one)
3. Form hypothesis: "removing X will reduce Y by Z%"
4. Implement ONE change, re-measure
5. Verify improvement is statistically significant (not noise)

## The 5 Whys — Root Cause Drill-Down

Surface errors rarely reveal root causes. Ask "why" recursively until you reach a fundamental cause you can permanently fix.

**Template:**
```
Symptom: [what the user/system reported]
Why 1: [immediate technical cause]
Why 2: [cause of the cause]
Why 3: [deeper system issue]
Why 4: [process or design flaw]
Why 5: [root cause — fixable permanently]
```

**Example:**
```
Symptom: API returns 500 on POST /users
Why 1: database insert throws ConstraintViolationError
Why 2: email field is empty string, violates NOT NULL constraint
Why 3: validation layer allows empty strings as valid email
Why 4: validation uses truthy check (empty string is falsy — wait, it isn't)
Why 5: regex validator has a bug — accepts empty string as valid email format
Root Fix: fix the email regex to require at least one character before @
```

**Stop when:** The why leads to an external system outside your control, a deliberate design decision, or a hardware/infrastructure limit. Those get a workaround, not a root fix.

**Stop asking why if:** You reach a fix that prevents ALL future instances of this class of bug — not just this specific instance.
