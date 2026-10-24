---
when:
    "*.rs *.c *.h *.cc *.cpp *.cxx *.hpp *.hh *.hxx *.py *.pyi *.ts *.tsx *.mts *.cts *.js *.jsx *.mjs *.cjs *.zig *.sh
    *.bash"
---

# Code

## Etiquette

- Be precise in what you propose and explain (what/why/where/current/future)
- Keep in mind that the user most often will not have the concrete code and problem at the top of his head. Therefore,
  provide context and explain from first principles.
- Never start writing code right away. Plan first and implement only when the user agreed.

## Workflow

- This project is interfaced using the tasks defined in Taskfile.yml. Building, testing, linting all run through `task`
  calls.
- We use test suites of stepped complexity (pre-commit/ci/nightly).
- Run `task pre` after completing substantial tasks for verification and validation.
- Test suite runs in pre-commit with max duration of 30 seconds.
- CI runs are limited to 10 minutes.
- Nightly runs are limited to 1 hour.

## Code Style

- Minimize re-exports
- use proper variable names - even traditional i, x, c can become index, value, count

## Modifications

- Keep SOLID principles in mind when adding or modifying code
- For hot paths we want Data-oriented Design (DOD)
- Make sure changes are minimal and reuse as much existent primitives as possible (YAGNI)
- For tests we target behavioural and numerical equivalence - no bit-for-bit exactness

## Code layout: blank lines around constructs (MANDATORY)

This rule is mandatory for all code you write or modify, in every language. It overrides any default tendency toward
compact code. A violation is a defect, just like a failing test.

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

Apply the rules to every construct you add or change, including the lines directly above and below it. Do not reformat
untouched code elsewhere.

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
