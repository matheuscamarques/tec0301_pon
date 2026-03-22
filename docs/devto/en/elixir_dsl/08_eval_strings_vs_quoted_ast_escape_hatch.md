---
title: "Building DSLs in Elixir (Part 8): eval strings vs quoted AST — a deliberate escape hatch"
published: false
description: "Part 8 of 10 — Sam draws a threat model; Riverbank chooses AST, staging, or eval. Mirrors build_defrule_string in Tec0301Pon.PON.Builder."
tags: elixir, metaprogramming, macros, dsl, code-eval
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 8): eval strings vs quoted AST — a deliberate escape hatch

**Part 8 of 10** — [Index](README.md) · [Part 7](07_multi_head_macros_and_alternative_shapes.md) · Next: [Part 9 — A second language on the same scaffold](09_layered_dsls_premises_conditions_examples.md)

**Reading time:** long-form draft (~10 min). Target **2,000+ words** per part.

---

The conference room smelled like coffee and dry erase. Sam taped a sticky labeled **THREAT MODEL** next to the projector. “If Ops edits a string in a table,” they said, “who can change that string? What can that person run as?” Maya’s idea—`when: "memoria[:x] > 1"` evaluated at runtime—was not *wrong* as physics; it was a **policy** question wearing syntax.

The codebase they were mirroring already split the world in two: AST `when:` for real application rules, and [`build_defrule_string/6`](../../../lib/tec0301_pon/pon/builder.ex) for the string path—`Code.eval_string/2` inside generated `avaliar/1`. The `@doc` on Builder warns: prefer AST in app code. Riverbank adopted the same split emotionally before they adopted it in code.

---

## From the codebase: what the string path generates

[`build_defrule_string/6`](../../../lib/tec0301_pon/pon/builder.ex) mirrors `build_defrule_ast/6` for module naming, `Module.concat`, `case acao` for instigations vs blocks, and `start_link` options—but **`avaliar/1`** differs sharply:

```elixir
def avaliar(memoria) do
  {result, _} = Code.eval_string(unquote(expr_string), memoria: memoria)
  result
end
```

The string is frozen at **compile time** as a literal in the module, but **evaluation** happens **whenever** `avaliar/1` runs. That means:

- **Performance:** eval work repeats per evaluation unless you optimize elsewhere (cache, fewer notifications).  
- **Security:** whoever controls the string content controls **full Elixir expressiveness** available inside `eval_string`—not “just comparisons.”  
- **Tooling:** `mix format`, credo, dialyzer, and IDE refactors do not see inside the string the way they see AST in source.

Part 6 contrasted **`var!(memoria)`** in the AST path with plain **`memoria`** here: the eval binding supplies `memoria:` explicitly; hygiene around the author’s **text** is a different problem—there is no spliced AST to align, only arbitrary code interpreted at runtime.

---

## What the PON series already said (string `when:`)

[Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md) shows a string `when:` example and warns: use sparingly; never feed untrusted input. This part is the **operational** unpacking: **what “untrusted” means** (supply chain, database rows, admin UIs, ticket bots), **how eval interacts with secrets** (strings can call code that reads `System.get_env/1`), and **how staging** can move strings back into AST at deploy time.

---

## From the tests: `RegrasWhenString`

[`builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs) defines `RegrasWhenString` with:

```elixir
when: "memoria[:builder_ws_x] > 10"
```

The test proves the string path **compiles** and **fires** under controlled facts. It is not a security test—it is a **behavior** anchor. Sam insisted Riverbank add **negative** tests too: strings that **raise** when facts missing, strings that return non-boolean garbage, and monitoring on eval failures in staging.

---

## The decision ladder Sam made them write (expanded)

**Default:** AST at the call site—tooling, compile errors, hygiene aligned with Part 6. Authors eat typos at `mix compile`, not at 2 a.m.

**If text must live in files:** compile with [`Code.string_to_quoted!/2`](https://hexdocs.pm/elixir/Code.html#string_to_quoted!/2) at **build or deploy** time, then emit normal modules—**no** runtime eval in prod. This recovers **syntax** checks once per release while keeping externalized text.

**If runtime eval is unavoidable:** treat strings as **full Elixir power**; log versions; **never** feed untrusted input; expect painful refactors; add **approval workflows** for any storage-backed rule text; rate-limit eval in hot paths if needed.

**If expressiveness must be bounded:** build a tiny interpreter over JSON or a safe predicate language—cheaper than incident response. OWASP’s code injection material applies the moment strings become programs.

**Staging rule:** mirror prod data shapes but **redact** secrets; run fuzz tests on string slots if they exist.

---

## OWASP-flavored questions for the whiteboard

- **Who can write** the string? (RBAC, audit logs, two-person review for prod?)  
- **Where is it stored**? (versioned table, git, object store?)  
- **How is it transported**? (TLS, signed bundles?)  
- **What breaks** if the string throws? (circuit breakers, dead-letter facts, operator alerts?)  
- **Can strings call** `apply/3`, `Code.eval_file/1`, or `System.cmd/3`? (Assume yes unless you sandbox.)

Sam’s punch line: **“If you wouldn’t give someone an `iex` session on the prod node, don’t give them eval strings either.”**

---

## Why Riverbank stayed on AST for the greenhouse core

`when: memoria[:x] > 1` in source keeps the condition in the **same** compilation unit as adapters and tests. The compiler argues with authors at dev time. Refactors rename consistently. Code review shows **diffs** humans can read.

String rules belong—if anywhere—in **controlled** subsystems: internal ops tools, superuser-only config, migration scripts—**not** in the default path for every irrigation author.

---

## Performance and observability notes

`Code.eval_string/3` builds and evaluates code repeatedly unless you intervene. For PON, `avaliar/1` may run often under notification bursts; [`Regra`](../../../lib/tec0301_pon/pon/regra.ex) batches some notifications, but eval cost remains **per evaluation**. Profile before blaming the network.

Telemetry: tag spans with **rule module atom** and a **hash** of the string (not the raw string) if logs might leak sensitive thresholds.

---

## If you must externalize safely (checklist)

1. Prefer **structured** predicates (JSON schema) → your own interpreter.  
2. Else **compile strings to modules** at deploy (build pipeline step).  
3. Else **whitelist** functions/macros available to eval (hard in Elixir; reconsider).  
4. Else run eval only on **offline** workers with **no** secrets in ENV.  
5. Never pass **user** input directly into `eval_string`.

---

## Process / prose: the ladder as a team ritual

Riverbank ran the ladder as a **design review gate** before any `when: "..."` appeared in `main`. Maya brought the use case; Jordan brought compile-time alternatives; Sam brought threat actors. If the meeting ended at “runtime eval,” they filed **security tasks**: audit, alert rules, on-call runbooks. If it ended at “deploy-time quote,” they filed **build tasks**: mix task or CI step, version pinning, rollback docs.

---

## Migration story: from strings back to AST

A contractor had stored fifty rules as strings in a database. Riverbank migrated by **parsing** each string with `Code.string_to_quoted!/2` in a one-off Mix task, **pretty-printing** the AST into a `.ex` file as `when: ...` expressions, and running tests. Some strings were **not** expressible as literals without refactoring—those became tickets. The migration was expensive; it paid for itself the first time `mix format` could run on conditions again.

---

## Compliance hooks: audit logs without eval noise

Sam required **append-only audit** rows for any string rule change: who, when, hash, environment. They did **not** log full strings if they contained customer thresholds—hash + vault pointer only. Elixir’s `:crypto.hash/2` on UTF-8 binaries worked; rotate audit retention per policy.

---

## Elixir version upgrades and eval

`Code.eval_string/3` behavior can shift subtly with language releases (warnings, deprecations). Pin CI matrix versions and run **`mix test`** on example suites that include `RegrasWhenString`. Riverbank added that module name to their upgrade checklist README—boring and effective.

---

## Tabletop exercise: “malicious intern” (15 minutes)

Team reads a fictional string rule proposed for prod: it calls `File.rm_rf!/1` if a sensor trips. Discussion prompts: Who approves merges to the rules table? Is there peer review? Can staging **prove** equivalence to a prior AST rule? Could a compromised CI bot inject text? The exercise ends with either **AST-only** policy or **HSM-backed signing** for rule blobs—Sam was fine with either if explicit.

---

## Cost/benefit prose for managers

Runtime eval buys **late binding** at the price of **static reasoning**. If the business truly needs daily rule edits without redeploys, budget **security + SRE** time alongside Elixir time. If edits are weekly, deploy-time quoting is cheaper overall. Riverbank’s COO understood the trade when framed as **insurance premiums** versus **deployment cadence**.

---

## Long-form threat narrative (fictional composite)

A greenhouse operator account was compromised through a reused password. The attacker could not SSH to nodes, but they **could** update rows in the rules table the UI exposed. Because one legacy path still used string `when:`, the attacker injected Elixir that exfiltrated environment variables through an outbound HTTP call hidden in a supposedly numeric threshold check. Detection took weeks because logs treated rule evaluation as **trusted internals**. The remediation bundle included: AST-only conditions in app code, row-level security on rule storage, signed deploy artifacts, and breaking the UI’s ability to write arbitrary text into eval’d slots. Elixir did not fail—**policy** failed. Part 8 exists so your team prices that story **before** it happens.

Sandbox fantasies (“we will run eval in a restricted VM someday”) are fine if funded. Unfunded fantasies belong in fiction, not `config/prod.exs`.

---

## Operator cheat sheet for incident response

When pager fires around dynamic rules: (1) identify whether the rule module uses `Code.eval_string/2` in `avaliar/1`—grep `_build` or read source; (2) freeze writes to the rule store; (3) snapshot DB rows + app version; (4) roll forward to AST-only build if available; (5) post-incident, add **`mix test`** covering string paths or delete them. Sam kept the cheat sheet next to the SSH bastion doc—outdated but directionally right.

## Red team notes: what still breaks AST-only policy

Even with AST `when:`, authors can call **`Code.eval_string/1`** inside the block—don’t laugh, it happened once in a “quick hack.” Lint privately with **credo custom checks** or forbid `Code.eval` in application directories. Sam’s longer-term fix was **code review ownership**: macro-heavy dirs required two reviewers, one from platform.

## Deeper dive: binding environment in `Code.eval_string/3`

The third argument is a keyword list of bindings—here, `memoria: memoria`. Anything you pass is available **inside** the evaluated string as variables. That means a malicious string can invoke **any** function visible in the evaluated context unless you sandbox (difficult on the BEAM for full Elixir). Restricting to “just comparisons” is **not** enforced by `eval_string`; you would need a separate interpreter. OWASP code-injection guidance therefore treats host-language eval as **maximum** privilege, not “half privilege.”

Riverbank’s platform team printed the allowed **whitelist** of modules/functions for non-DSL code paths; eval’d rules were either removed or rewritten to call only those whitelisted functions through thin wrappers—still fragile, but better than raw eval with full `Kernel`.

For audits, Sam asked: “Show me the **smallest** string that can `File.read!/1` a path.” If the team could construct one in under five minutes, the feature failed the review.

---

## Next: stacking languages without stacking confusion

Maya realized one macro family would not carry every sentence the greenhouse spoke. She sketched **premises** and **aggregate conditions** on the whiteboard—second layers that still expand to `start_link` children, like [`defpremissa` and `defcondicao`](../../../lib/tec0301_pon/pon/builder.ex). [Part 9](09_layered_dsls_premises_conditions_examples.md) walks that hallway.

---

## A footnote for the curious (literature)

Meta-circular eval is classic Lisp; `Code.eval_string/3` is Elixir’s lever—and OWASP’s injection material applies when strings become code. Fowler and Voelter both insist externalized notations need **defined semantics** and tooling; raw host-language strings are the weakest external DSL. Taha’s staging (1999) names the middle path: compile strings **once** at a boundary, recover static checks.

McCord discusses eval sparingly—*Metaprogramming Elixir* pushes AST first. For historical hygiene contrast, see Kohlbecker et al. in Part 6’s bibliography—hygiene fixes accidental capture; eval reopens intentional **dynamic** scope. [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md).

---

## See also (cross-links)

Eval strings are the **exception** path introduced in Part [7](07_multi_head_macros_and_alternative_shapes.md)’s binary `when:` heads; undoing them touches the same four clauses. Re-read Part [6](06_hygiene_and_var_bang_injecting_memoria_safely.md) for `executar` asymmetry between AST and string builders. Part [10](10_testing_and_inspecting_macros.md) names `RegrasWhenString` as the regression anchor. Layered DSLs in Part [9](09_layered_dsls_premises_conditions_examples.md) should **default** to AST conditions unless a written exception exists. Treat every string slot as **privileged** code until proven otherwise.

If you maintain both AST and string paths, schedule **quarterly** joint reviews: security, platform, and the rule authors. The agenda is short: inventory string sources, verify access controls, and confirm tests still execute both branches in CI.

---

## References

- Elixir [`Code.eval_string/3`](https://hexdocs.pm/elixir/Code.html#eval_string/3), [`Code.string_to_quoted!/2`](https://hexdocs.pm/elixir/Code.html#string_to_quoted!/2).
- Fowler, M. (2010). *Domain-Specific Languages*; Voelter, M.; et al. (2013). *DSL Engineering*.
- Taha, W. (1999). *Multi-stage programming* (thesis).
- OWASP — [Code injection](https://owasp.org/www-community/attacks/Code_Injection).
- [`build_defrule_string`](../../../lib/tec0301_pon/pon/builder.ex); [`builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs).

[BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
