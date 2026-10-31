# Agents

Global instructions for every repository. A repository's own AGENTS.md is loaded after this file and wins where the two
conflict.

## Etiquette

- Be precise in what you propose and explain (what/why/where/current/future)
- When I ask for an explanation, keep in mind that I most often will not have the concrete code and problem at the top
  of my head. Provide context and explain from first principles.
- Never start writing code right away. Plan first and implement only when I agreed.

## Think before coding

- State your assumptions explicitly. If something is unclear, stop, name what is confusing, and ask.
- If the goal is unclear, ask before planning. If only the design is open, decide: give one recommendation and why, not
  a list of options.
- If a simpler approach exists, say so. Push back when warranted.

## Simplicity first

- Make sure changes are minimal and reuse as much existent primitives as possible (YAGNI)
- No features beyond what was asked, no abstractions for single-use code, no configurability that was not requested, no
  error handling for impossible cases.
- Keep SOLID principles in mind when adding or modifying code
- For hot paths we want Data-oriented Design (DOD)

## Surgical changes

- Touch only what the task needs. Do not "improve" adjacent code, comments or formatting, and do not refactor what is
  not broken.
- Match existing style, even if you would do it differently.
- If you notice unrelated dead code or problems, mention them; do not fix them unasked.
- Remove imports, variables and functions that your changes made unused, and nothing else.
- Every changed line should trace directly to the request.

## Goal-driven execution

- Turn the task into verifiable goals: "fix the bug" becomes "write a test that reproduces it, then make it pass".
- For multi-step tasks, state a brief plan with a check for each step, and loop until every check passes.
- For tests we target behavioural and numerical equivalence - no bit-for-bit exactness

## Code style

- Minimize re-exports, prefer clean logical structure that is reflected in code organization as well
- use proper variable names - even traditional i, x, c can become index, value, count

## Code layout: blank lines around constructs (MANDATORY)

This rule is mandatory for all new code you write, in every language. It overrides any default tendency toward compact
code. A violation is a defect, just like a failing test.

The goal: control flow must be visible at a glance. A construct is always set apart by blank lines. Elsewhere, a blank
line is optional and marks a conceptual break.

### Definitions

- **Construct**: a statement that owns a block of statements. Examples: `if`/`else`, `match`/`switch`,
  `for`/`while`/`loop`/`do`, `try`/`catch`/`finally`, `with`/`using`, `unsafe`/`defer`/bare `{ }` blocks, nested
  function definitions, and any statement that contains a multi-line `if`/`match` expression or a closure with a
  statement body. All branches of one construct (`if` + `else if` + `else`, `try` + `catch` + `finally`) count as one
  construct.
- **Straight-line code**: every other statement (declarations, assignments, calls, `return`, `break`, `continue`).
  One-line conditional expressions (`a ? b : c`, `x if c else y`, comprehensions) are straight-line code.

### Rules

1. **Adjacent-pair rule.** Between two adjacent statements at the same nesting level, there must be exactly one blank
   line if at least one of them is a construct:

    | upper statement | lower statement | blank line        |
    | --------------- | --------------- | ----------------- |
    | straight-line   | straight-line   | optional (rule 2) |
    | straight-line   | construct       | required          |
    | construct       | straight-line   | required          |
    | construct       | construct       | required          |

2. Between two straight-line statements, a blank line is optional. Use it only to mark a conceptual break (e.g. setup
   vs. computation).
3. No blank line at the start or end of a block: nothing between an opening line (signature, `{`, `:`, branch header)
   and the first statement, and nothing between the last statement and the closing line. These lines are not statements,
   so rule 1 never applies to them. A construct that is the first or last statement of its block therefore gets no blank
   line on that side, and directly nested constructs have no blank lines between them.
4. No blank lines between the branches of one construct.
5. Never more than one consecutive blank line inside a body.
6. A comment describing a construct sits directly above it; the blank line goes above the comment.
7. The rules apply recursively inside every block.
8. Spacing between top-level items (functions, classes, impls, modules) follows the language's normal convention. This
   rule governs bodies.

### Editing existing code

Apply the rules to the code you add. In existing code, the surrounding style and the repo formatter win; do not re-space
lines you did not write.

### Formatters

Formatters do not enforce this rule. Insert the blank lines yourself, run the project formatter, then confirm the result
still satisfies every rule above.

### Examples

Correct (Rust):

```rust
fn process(items: &[Item], cfg: &Config) -> Result<u32, Error> {
    let limit = cfg.limit();
    let mut total = 0;

    for item in items {
        if item.is_valid() {
            if item.weight > limit {
                return Err(Error::TooHeavy);
            } else {
                total += item.weight;
            }
        }
    }

    let scaled = total * cfg.scale();
    log::debug!("total = {scaled}");

    match cfg.mode {
        Mode::Fast => fast_path(scaled),
        Mode::Safe => safe_path(scaled),
    }
}
```

Correct (Python):

```python
def load(path):
    if not path.exists():
        raise FileNotFoundError(path)

    text = path.read_text()
    rows = []

    for line in text.splitlines():
        if line.startswith("#"):
            continue

        rows.append(parse(line))

    return rows
```

Wrong (constructs not separated from straight-line code):

```python
def load(path):
    if not path.exists():
        raise FileNotFoundError(path)
    text = path.read_text()
    rows = []
    for line in text.splitlines():
        if line.startswith("#"):
            continue
        rows.append(parse(line))
    return rows
```

Wrong (blank lines at block start/end and between directly nested constructs):

```python
def load(path):

    for line in path.read_text().splitlines():

        if line.startswith("#"):
            continue

    return None
```

Wrong (sibling constructs not separated):

```python
    if a:
        x()
    if b:
        y()
```

### Self-check before finishing

For every changed hunk, look at the line directly above and directly below each construct and apply rules 1, 3 and 4.
Fix every violation before reporting the task as done.
