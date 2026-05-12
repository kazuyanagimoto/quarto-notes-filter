# quarto-notes-filter

A Quarto filter extension that adds **AER-style notes** — a "Notes:" line
in a smaller font, rendered just below a figure caption (`fig-notes`) or
below a table (`tbl-notes`, in the spirit of `tinytable`'s `notes`
option), still inside the float.

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

or `tbl-notes` to any Markdown table:

```markdown
| a   | b   |
| --- | --- |
| 1   | 2   |

: A table caption. {#tbl-x tbl-notes="Source: Doe (2024)."}
```

For executable cells, use it as a chunk option (Quarto passes `fig-*` /
`tbl-*` options through to the produced figure or table):

````markdown
```{r}
#| label: fig-x
#| fig-cap: "A caption."
#| fig-notes: "Source: Doe (2024)."
plot(1:10)
```
````

### Options

| Option            | Scope                 | Default    | Description                                                                                                                                             |
| ----------------- | --------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fig-notes`       | per-figure            | _(none)_   | Notes text for a figure. Inline Markdown, cross-references (`@sec-x`, `@fig-x`), and citations (`@cite-key`) are supported. Rendered below the caption. |
| `fig-notes-title` | per-figure / document | `"Notes:"` | Prefix shown before the figure notes, rendered in italics.                                                                                              |
| `fig-notes-scale` | per-figure / document | `0.9`      | Font size of figure notes relative to body text (i.e., `0.9em`, AER-style).                                                                             |
| `tbl-notes`       | per-table             | _(none)_   | Notes text for a table. Same Markdown / crossref / citation support as `fig-notes`. Rendered below the table.                                           |
| `tbl-notes-title` | per-table / document  | `"Notes:"` | Prefix shown before the table notes, rendered in italics.                                                                                               |
| `tbl-notes-scale` | per-table / document  | `0.9`      | Font size of table notes relative to body text.                                                                                                         |

Document-level defaults go in the YAML front matter:

```yaml
fig-notes-title: "Notes:"
fig-notes-scale: 0.9
tbl-notes-title: "Notes:"
tbl-notes-scale: 0.9
```

Per-figure / per-table values override document-level defaults.

### LaTeX size mapping

For LaTeX/PDF output the `fig-notes-scale` / `tbl-notes-scale` value is
mapped to a standard LaTeX size command (at a 10pt body):

| scale     | LaTeX command   | Approx. size |
| --------- | --------------- | ------------ |
| `<= 0.75` | `\scriptsize`   | ~7pt         |
| `<= 0.85` | `\footnotesize` | ~8pt         |
| `<= 0.95` | `\small`        | ~9pt         |
| `<= 1.05` | `\normalsize`   | ~10pt        |
| `> 1.05`  | `\large`        | ~12pt        |

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

## License

MIT. See [LICENSE](LICENSE).
