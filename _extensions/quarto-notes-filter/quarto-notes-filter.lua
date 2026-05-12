
--[[
quarto-notes-filter
-------------------
Adds AER-style "Notes:" text below a figure caption.

Usage
-----
Static figure:
  ![Caption](img.png){#fig-x fig-notes="Source: ..." fig-notes-title="Notes:"}

Executable cell (Quarto passes fig-* chunk options through to the figure's
underlying image):
  #| fig-cap: "My caption"
  #| fig-notes: "Source: ..."

Document-level defaults (YAML front matter):
  fig-notes-title: "Notes:"   # default "Notes:"
  fig-notes-scale: 0.9        # default 0.9 (fraction of body fontsize, AER-style)
]]

local default_title = "Notes:"
local default_scale = 0.9

-- Document-level defaults.
function Meta(meta)
  if meta["fig-notes-title"] ~= nil then
    default_title = pandoc.utils.stringify(meta["fig-notes-title"])
  end
  if meta["fig-notes-scale"] ~= nil then
    local s = tonumber(pandoc.utils.stringify(meta["fig-notes-scale"]))
    if s ~= nil then default_scale = s end
  end
end

-- Parse a string of inline markdown into a Pandoc Inlines list.
local function parse_inlines(s)
  if s == nil or s == "" then return pandoc.Inlines({}) end
  local doc = pandoc.read(s, "markdown")
  return pandoc.utils.blocks_to_inlines(doc.blocks)
end

-- Escape text so it can sit inside a Typst content block `[ ... ]`.
local function typst_escape(s)
  return (s:gsub("\\", "\\\\")
           :gsub("%[", "\\[")
           :gsub("%]", "\\]"))
end

-- Build a list of Inlines that renders the notes line in Typst. The
-- notes content is passed through as real Pandoc Inlines (rather than
-- being pre-serialized via `pandoc.write`) so that any `Cite` or
-- cross-reference inlines survive intact and are later resolved by
-- Quarto's citeproc / crossref filters.
local function build_typst_notes(title, notes_inlines, scale)
  local title_typ = typst_escape(title)
  local open = pandoc.RawInline("typst", string.format(
    "\n#block(width: 100%%, above: 1.5em, below: 0em)[#align(left)[#text(size: %sem)[#emph[%s] ",
    tostring(scale), title_typ
  ))
  local close = pandoc.RawInline("typst", "]]]")
  local result = pandoc.Inlines({ open })
  for _, inl in ipairs(notes_inlines) do result:insert(inl) end
  result:insert(close)
  return result
end

-- LaTeX font-size command for a given scale relative to the body fontsize.
-- Approximate mapping at 10pt body:
--   \scriptsize    ~ 7pt    (0.7em)
--   \footnotesize  ~ 8pt    (0.8em)
--   \small         ~ 9pt    (0.9em, AER-style default)
--   \normalsize    ~ 10pt   (1.0em)
local function latex_size_cmd(scale)
  if scale <= 0.75 then return "\\scriptsize"
  elseif scale <= 0.85 then return "\\footnotesize"
  elseif scale <= 0.95 then return "\\small"
  elseif scale <= 1.05 then return "\\normalsize"
  else return "\\large"
  end
end

-- Escape a plain string for LaTeX.
local function latex_escape(s)
  return (s:gsub("\\", "\\textbackslash{}")
           :gsub("([&%%$#_{}])", "\\%1")
           :gsub("~", "\\textasciitilde{}")
           :gsub("%^", "\\textasciicircum{}"))
end

-- Build a list of Inlines that renders the notes line in LaTeX. As with
-- the Typst variant, the notes content is left as real Pandoc Inlines
-- so that `Cite` / cross-reference inlines are resolved later by
-- Quarto's citeproc / crossref filters.
local function build_latex_notes(title, notes_inlines, scale)
  local title_tex = latex_escape(title)
  local size_cmd = latex_size_cmd(scale)
  local open = pandoc.RawInline("latex", string.format(
    "\\newline\\rule{0pt}{1.6ex}\\newline\\protect\\parbox[t]{\\linewidth}{\\raggedright %s\\emph{%s} ",
    size_cmd, title_tex
  ))
  local close = pandoc.RawInline("latex", "}")
  local result = pandoc.Inlines({ open })
  for _, inl in ipairs(notes_inlines) do result:insert(inl) end
  result:insert(close)
  return result
end

-- Track whether the global LaTeX captionsetup has been injected
-- (we only need it once per document).
local latex_captionsetup_injected = false

-- Inject (once) a global LaTeX `\captionsetup{...}` so that the figure
-- caption is rendered ragged-right with no hanging indent. This is
-- needed because our injected notes paragraph turns the caption into
-- multi-line content, and the `caption` package's default multi-line
-- behavior is to hang-indent under the label ("Figure N:"), which
-- would push the notes paragraph in from the figure's left edge.
-- The ragged-right setup keeps both the caption text and the notes
-- flush at the figure's left edge.
local function inject_latex_captionsetup()
  if latex_captionsetup_injected then return end
  latex_captionsetup_injected = true
  quarto.doc.include_text(
    "in-header",
    "\\captionsetup{format=plain,justification=centering,singlelinecheck=off,indention=0pt}\n"
  )
end


-- Escape a plain string for HTML attribute / text contexts.
local function html_escape(s)
  return (s:gsub("&", "&amp;")
           :gsub("<", "&lt;")
           :gsub(">", "&gt;"))
end

-- Build a list of Inlines that renders the notes line in HTML. As with
-- the Typst / LaTeX variants, the notes content stays as real Pandoc
-- Inlines so that `Cite` / cross-reference inlines are resolved later.
local function build_html_notes(title, notes_inlines, scale)
  local title_html = html_escape(title)
  local style = string.format(
    "margin-top:1.5em;text-align:left;font-size:%sem;",
    tostring(scale)
  )
  local open = pandoc.RawInline("html", string.format(
    '<div class="quarto-figure-notes" style="%s"><em>%s</em> ',
    style, title_html
  ))
  local close = pandoc.RawInline("html", "</div>")
  local result = pandoc.Inlines({ open })
  for _, inl in ipairs(notes_inlines) do result:insert(inl) end
  result:insert(close)
  return result
end


local function find_image(blocks)
  if blocks == nil then return nil end
  for _, b in ipairs(blocks) do
    if b.t == "Plain" or b.t == "Para" then
      for _, inl in ipairs(b.content) do
        if inl.t == "Image" then return inl end
      end
    elseif b.t == "Div" then
      local r = find_image(b.content)
      if r then return r end
    end
  end
  return nil
end

function FloatRefTarget(float)
  local content_blocks = quarto.utils.as_blocks(float.content)
  local img = find_image(content_blocks)
  if img == nil then return nil end

  local notes_raw = img.attributes["fig-notes"]
  if notes_raw == nil or notes_raw == "" then return nil end

  local title = img.attributes["fig-notes-title"] or default_title
  local scale = tonumber(img.attributes["fig-notes-scale"] or "") or default_scale

  -- Strip handled attributes so they don't leak into output.
  img.attributes["fig-notes"] = nil
  img.attributes["fig-notes-title"] = nil
  img.attributes["fig-notes-scale"] = nil

  local notes_inlines = parse_inlines(notes_raw)

  local function append_inlines(inlines)
    if float.caption_long == nil then
      float.caption_long = pandoc.Plain(inlines)
      return
    end
    if float.caption_long.t == "Plain" or float.caption_long.t == "Para" then
      for _, inl in ipairs(inlines) do
        float.caption_long.content:insert(inl)
      end
      return
    end
    -- caption_long is a Div or block list; append as a Plain block.
    float.caption_long.content:insert(pandoc.Plain(inlines))
  end

  if quarto.doc.is_format("typst") then
    append_inlines(build_typst_notes(title, notes_inlines, scale))
    return float
  end

  if quarto.doc.is_format("latex") or quarto.doc.is_format("pdf") then
    inject_latex_captionsetup()
    append_inlines(build_latex_notes(title, notes_inlines, scale))
    return float
  end

  if quarto.doc.is_format("html") then
    append_inlines(build_html_notes(title, notes_inlines, scale))
    return float
  end

  return nil
end

