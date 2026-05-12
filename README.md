# quarto-notes-filter

A Quarto filter extension that adds **AER-style figure notes** — a
"Notes:" line in a smaller font, rendered just below the figure caption
and still inside the figure float.

Quarto does not currently provide this out of the box (see
[quarto-dev/quarto-cli#7514](https://github.com/quarto-dev/quarto-cli/issues/7514)).
This extension fills that gap.

**Supported formats:** Typst, LaTeX/PDF, HTML.

## Installing

```bash
quarto add Kazuharu-Yanagimoto/quarto-notes-filter
```

## Usage

Enable the filter in your document's YAML:

```yaml
filters:
  - quarto-notes-filter
```

Add `fig-notes` to any figure:

```markdown
![A caption.](img.png){#fig-x fig-notes="Source: Doe (2024)."}
```

For executable cells, use it as a chunk option (Quarto passes `fig-*` options
through to the produced figure):

````markdown
```{r}
#| label: fig-x
#| fig-cap: "A caption."
#| fig-notes: "Source: Doe (2024)."
plot(1:10)
```
````

### Options

| Option            | Scope                 | Default    | Description                                                                                                    |
| ----------------- | --------------------- | ---------- | -------------------------------------------------------------------------------------------------------------- |
| `fig-notes`       | per-figure            | _(none)_   | Notes text. Inline Markdown, cross-references (`@sec-x`, `@fig-x`), and citations (`@cite-key`) are supported. |
| `fig-notes-title` | per-figure / document | `"Notes:"` | Prefix shown before the notes text, rendered in italics.                                                       |
| `fig-notes-scale` | per-figure / document | `0.9`      | Font size relative to body text (i.e., `0.9em`, AER-style).                                                    |

Document-level defaults go in the YAML front matter:

```yaml
fig-notes-title: "Notes:"
fig-notes-scale: 0.9
```

Per-figure values override document-level defaults.

### LaTeX size mapping

For LaTeX/PDF output the `fig-notes-scale` value is mapped to a standard
LaTeX size command (at a 10pt body):

| `fig-notes-scale` | LaTeX command   | Approx. size |
| ----------------- | --------------- | ------------ |
| `<= 0.75`         | `\scriptsize`   | ~7pt         |
| `<= 0.85`         | `\footnotesize` | ~8pt         |
| `<= 0.95`         | `\small`        | ~9pt         |
| `<= 1.05`         | `\normalsize`   | ~10pt        |
| `> 1.05`          | `\large`        | ~12pt        |

The AER-style default `0.9` therefore renders as `\small`.

## Example

See [example.qmd](example.qmd) for a complete example that renders to all
three supported formats and demonstrates cross-references and citations
inside notes:

```bash
quarto render example.qmd --to html
quarto render example.qmd --to pdf
quarto render example.qmd --to typst
```
