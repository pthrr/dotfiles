# Formatting Notes

## Math delimiters

- Inline: `$...$` — `$t_A(x)$`, `$d_{ij}$`.
- Display: `$$...$$` on separate lines, with a blank line before and after.
- Do not use `\(...\)` or `\[...\]`; Obsidian expects dollar delimiters.
- Inside code spans and fences, math stays literal: `` `$...$` ``.

## What must be math

Format every mathematical object, not only equations:

| Raw            | Formatted                     |
| -------------- | ----------------------------- |
| `t_A(x)`       | `$t_A(x)$`                    |
| `d_ij`         | `$d_{ij}$`                    |
| `2^n`          | `$2^n$`                       |
| `n <= m`       | `$n \le m$`                   |
| `NP = P`       | `$\mathrm{NP} = \mathrm{P}$`  |
| `O(n log n)`   | `$O(n \log n)$`               |
| `Sigma`        | `$\Sigma$`                    |
| `->`           | `$\to$`                       |

This covers variables, subscripts and superscripts, Greek letters, operators
(`\le`, `\ge`, `\neq`, `\in`, `\notin`, `\subseteq`, `\to`, `\mapsto`), sets
(`\mathbb{N}`, `\mathbb{R}`), sums and products (`\sum`, `\prod`), norms
(`|x|`, `\lVert x \rVert`), complexity classes (`\mathrm{P}`, `\mathrm{NP}`),
and runtime or space functions (`t_A(n)`, `S_A(n)`).

## Multi-letter names

Use `\text{}` or `\mathrm{}` so names do not render as products of variables:

- `$\text{TSP}_{\text{opt}}$`, `$\text{Sat}_{\text{circ}}$`
- `$\text{CNF-Sat}$`, `$\text{Max-}k\text{-Sat}$`
- `$\mathrm{NP} = \mathrm{P}$`

Hyphens inside names belong inside `\text{}`: `$\text{CNF-Sat}$`.

## Prose

- Do not leave ASCII math in prose: `t_A(x)`, `2^n`, `NP = P`, `->`.
- When `=` or `+` is only prose, rephrase instead of forcing math:
  "the circuit is a permutation", not "circuit = permutation";
  "the algorithm and the input", not "algorithm + input".
- Use `$\to$` for implications, not `->`.
- Keep each `$...$` on one line; do not put blank lines inside it.
- Escape a literal dollar sign as `\$`.

## Display math

Use display math for standalone definitions and multi-line derivations:

$$
t_A(n) := \sup\{t_A(x) : |x| \le n\}
$$

- Keep display blocks outside bullets when possible. Inside a bullet, indent the
  block to the bullet's content.
- Align multi-line derivations with `\begin{aligned}...\end{aligned}`.

## Common pitfalls

- `*` outside math is emphasis; use `\cdot` or `\times` inside math.
- `<` and `>` can be parsed as HTML outside math; use `$\lt$` / `$\gt$` or keep
  them inside math.
- `|` outside math can split tables; use `$|x|$` or `\vert`.
- Underscores outside math may be literal or emphasis depending on context;
  always use math for subscripts.
- An odd number of `$` on a line breaks the rest of the note; check pairing per
  line.
- MathJax does not support every LaTeX package; stick to commands with
  `amsmath` or `amssymb` equivalents.

## Quick check

- Every variable, subscript and operator is inside `$...$`.
- No raw `->`, `<=`, `>=`, `!=`, `sum`, `Sigma`, `Theta` or `Omega` in prose.
- Every line has an even number of `$`.
- Braces balance inside each math span.
- Preview the note in Obsidian before staging.
