# Bibliography — Building DSLs in Elixir (EN series)

Normalized references for [`docs/devto/en/elixir_dsl/`](./). Use these tables when publishing on dev.to or in academic slides; verify URLs periodically.

The long-form posts in this folder cite this bibliography from their “footnote for the curious” sections and **References** lists—keep rows stable when URLs move.

For Erlang/OTP, Phoenix, and PON-specific citations, see also [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).

## Domain-specific languages and language workbenches

| Author(s) | Year | Title | Notes / where |
|-----------|------|--------|----------------|
| Fowler, M. | 2010 | *Domain-Specific Languages* | Addison-Wesley — taxonomy of **internal vs external** DSLs, fluent interfaces, decision frameworks for when a DSL pays off ([author’s page](https://martinfowler.com/books/dsl.html)). |
| Voelter, M.; et al. | 2013 | *DSL Engineering: Designing, Implementing and Using Domain-Specific Languages* | Comprehensive methodology: requirements, notation, semantics, tooling ([dslbook.org](http://dslbook.org/)). |

## Metaprogramming, macros, and hygiene

| Author(s) | Year | Title | Notes / where |
|-----------|------|--------|----------------|
| Kohlbecker, E.; Friedman, D. P.; Felleisen, M.; Duba, B. | 1986 | *Hygienic macro expansion* | *ACM Conference on Lisp and Functional Programming* — classic definition of **hygiene** and capture-avoiding expansion ([DOI 10.1145/319838.319859](https://doi.org/10.1145/319838.319859)). |
| Clinger, W. | 1991 | *Macros that work* | *POPL* — properties of reliable macro expansion (hygiene, referential transparency of macro expansion). |
| Flatt, M. | 2016 | *Binding as sets of scopes* | *SNAPL* — modern account of binding (Racket); optional background when comparing `var!` to host-language binding models ([dagstuhl.de](https://drops.dagstuhl.de/opus/volltexte/2016/6113/)). |
| Krishnamurthi, S. | 2007+ | *Programming Languages: Application and Interpretation* (PLAI) | Free textbook; **macros and code as data** treated with interpreters ([Brown CS edition](https://cs.brown.edu/~sk/Publications/Books/ProgLangs/2007-04-26/)). |
| McCord, C. | 2015 | *Metaprogramming Elixir* | Pragmatic Bookshelf — `quote`/`unquote`, `__using__`, testing macros in Elixir. |

## Staging: compile-time vs runtime

| Author(s) | Year | Title | Notes / where |
|-----------|------|--------|----------------|
| Taha, W. | 1999 | *Multi-stage programming: its theory and applications* (PhD thesis) | Foundational **staging** intuition: separate compile-time computation from runtime ([Oregon Graduate Institute](https://www.cs.rice.edu/~taha/publications/thesis/taha-thesis.pdf) mirror; search if link moves). |
| *Elixir* | — | `Kernel.SpecialForms.quote/2`, `Macro.expand/2` | Official docs tie **macro expansion** to compile pipeline ([hexdocs.pm/elixir](https://hexdocs.pm/elixir/)). |

## Language implementation (parsing, modules, environments)

| Author(s) | Year | Title | Notes / where |
|-----------|------|--------|----------------|
| Parr, T. | 2010 | *Language Implementation Patterns* | Pragmatic — patterns for trees, symbols, scopes; useful analogy for **AST manipulation** and generated definitions. |
| Armstrong, J. | 2003 | *Making reliable distributed systems…* (PhD thesis) | Code loading, modules, hot upgrade — context for **generated modules** and named functions ([erlang.org PDF](https://www.erlang.org/download/armstrong_thesis_2003.pdf)). |
| Cesarini, F.; Thompson, S. | 2016 | *Programming Erlang (2nd ed.)* | OTP, processes, code structure. |

## Reactive rules and notification-oriented context (cross-links)

| Author(s) | Year | Title | Notes / where |
|-----------|------|--------|----------------|
| Simão, J. M.; et al. | 2013 | *NOP and Imperative Paradigm: A Comparative Study* | Academic NOP framing; pairs with this repo’s PON DSL ([IJSEA / SCIRP](https://www.scirp.org/journal/paperinformation?paperid=19842)). |

## Evaluation, security, and “eval is evil”

| Author(s) | Year | Title | Notes / where |
|-----------|------|--------|----------------|
| *OWASP* | — | Code injection / unsafe deserialization | General security backdrop when discussing `eval_string` on untrusted input ([owasp.org](https://owasp.org/)). |
| *Elixir* | — | `Code.eval_string/3` documentation | Documents binding and risks in host language terms ([hexdocs.pm/elixir/Code.html](https://hexdocs.pm/elixir/Code.html#eval_string/3)). |

## Testing and software engineering

| Author(s) | Year | Title | Notes / where |
|-----------|------|--------|----------------|
| Meszaros, G. | 2007 | *xUnit Test Patterns* | **Test doubles**, suite layering — supports “test generated code via behavior, not only AST” ([xunitpatterns.com](http://xunitpatterns.com/)). |

---

**Source of truth:** this file in the repository. When a post cites “Fowler (2010)” or “Kohlbecker et al. (1986)”, expand to the row above for publisher pages and DOIs.
