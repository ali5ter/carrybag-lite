#!/usr/bin/env python3
"""PDF to Markdown converter.

Converts a PDF file to Markdown, preserving headings, paragraphs,
lists, and inline bold/italic formatting. Uses PyMuPDF (fitz) to
extract text with font-size and style metadata, then maps that metadata
to Markdown heading levels, bold/italic, and list items. Works best
with text-based PDFs; scanned images are not supported.

Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
Version: 1.2.0
Date: 2026-04-25
License: MIT

Usage:
    pdf2md.py [OPTIONS] <input.pdf> [output.md]

Dependencies:
    pymupdf (pip install pymupdf)

Exit codes:
    0 - Success
    1 - File not found or unreadable
    2 - Missing dependency
"""

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

try:
    import fitz  # PyMuPDF
except ImportError:
    print(
        "Error: pymupdf is required. Install it with:\n"
        "  pip install pymupdf",
        file=sys.stderr,
    )
    sys.exit(2)


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Span:
    """A single run of text with uniform style."""

    text: str
    size: float
    flags: int   # PyMuPDF bitmask: 1=super, 2=italic, 4=serif, 8=mono, 16=bold
    color: int
    origin_y: float  # vertical position on page (used for sort order)
    origin_x: float  # horizontal position on page


@dataclass
class Block:
    """A rectangular block of text spans on one page."""

    page: int
    bbox_y: float   # top-y of bounding box (sort key)
    bbox_x: float   # left-x of bounding box (sort key)
    spans: list[Span] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

def extract_blocks(doc: fitz.Document) -> list[Block]:
    """Extract all text blocks from every page, sorted top-to-bottom.

    Args:
        doc: An open PyMuPDF Document object.

    Returns:
        A flat list of Block objects in reading order (page → y → x).
    """
    blocks: list[Block] = []
    for page_num in range(len(doc)):
        page = doc[page_num]
        raw = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)
        for raw_block in raw.get("blocks", []):
            if raw_block.get("type") != 0:  # skip images
                continue
            block = Block(
                page=page_num,
                bbox_y=raw_block["bbox"][1],
                bbox_x=raw_block["bbox"][0],
            )
            for line in raw_block.get("lines", []):
                for span in line.get("spans", []):
                    text = span.get("text", "")
                    if not text.strip():
                        continue
                    block.spans.append(
                        Span(
                            text=text,
                            size=round(span.get("size", 0), 1),
                            flags=span.get("flags", 0),
                            color=span.get("color", 0),
                            origin_y=span.get("origin", (0, 0))[1],
                            origin_x=span.get("origin", (0, 0))[0],
                        )
                    )
            if block.spans:
                blocks.append(block)

    return sorted(blocks, key=lambda b: (b.page, b.bbox_y, b.bbox_x))


# ---------------------------------------------------------------------------
# Filtering heuristics
# ---------------------------------------------------------------------------

# Colors that appear exclusively in footers/headers of Canva-style PDFs.
_FOOTER_COLORS: frozenset[int] = frozenset({9079434})

# Patterns that always indicate noise regardless of font size.
_ALWAYS_NOISE_PATTERNS: tuple[re.Pattern, ...] = (
    re.compile(r"ageisjustanumber\.co", re.IGNORECASE),
    re.compile(r"Age Is Just a? ?Number", re.IGNORECASE),
)

# Patterns that indicate noise only in small-size text (footer/watermark).
# For example, "AJUN 3Cs Framework" is a footer at 12 pt but the document
# title at 41 pt — filter only the footer instance.
_FOOTER_ONLY_PATTERNS: tuple[re.Pattern, ...] = (
    re.compile(r"^AJUN\s+3Cs\s+Framework\s*$", re.IGNORECASE),
)
_FOOTER_SIZE_MAX: float = 14.0  # apply footer-only patterns at or below this size

# Standalone trademark / registered-mark symbols that carry no content.
_TRADEMARK_RE: re.Pattern = re.compile(
    r"^[™®℠]+$|^TM$|^\(TM\)$|^\(R\)$", re.IGNORECASE
)

# Standalone page-number pattern: one to three digits, nothing else.
_PAGE_NUMBER_RE: re.Pattern = re.compile(r"^\s*\d{1,3}\s*$")


def is_noise(span: Span) -> bool:
    """Return True if the span is footer/watermark/trademark noise.

    Args:
        span: The Span to evaluate.

    Returns:
        True when the span should be suppressed in output.
    """
    # Superscript symbols (e.g. ™ rendered as superscript)
    if span.flags & 1:  # bit 0 = superscript
        return True
    # Footer-coloured text
    if span.color in _FOOTER_COLORS:
        return True
    stripped = span.text.strip()
    # Standalone trademark symbols (e.g. "TM" placed next to a logo)
    if _TRADEMARK_RE.match(stripped):
        return True
    # Always-noise text patterns
    for pat in _ALWAYS_NOISE_PATTERNS:
        if pat.search(stripped):
            return True
    # Footer-only text patterns (suppress only in small-font context)
    if span.size <= _FOOTER_SIZE_MAX:
        for pat in _FOOTER_ONLY_PATTERNS:
            if pat.match(stripped):
                return True
    return False


def is_page_number_block(block: Block) -> bool:
    """Return True when a block contains only a standalone page number.

    Args:
        block: The Block to evaluate.

    Returns:
        True when the block should be suppressed entirely.
    """
    texts = [s.text.strip() for s in block.spans if s.text.strip()]
    return bool(texts) and all(_PAGE_NUMBER_RE.match(t) for t in texts)


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

_BOLD_FLAG   = 16  # PyMuPDF flag bit for bold
_ITALIC_FLAG = 2   # PyMuPDF flag bit for italic


def is_bold(span: Span) -> bool:
    """Return True if the span is bold."""
    return bool(span.flags & _BOLD_FLAG)


def is_italic(span: Span) -> bool:
    """Return True if the span is italic."""
    return bool(span.flags & _ITALIC_FLAG)


def classify_heading_level(size: float, bold: bool) -> int | None:
    """Map a font size + bold flag to a Markdown heading level.

    Only spans at 20 pt or larger are eligible for headings.  Bold text
    at 18 pt or below is treated as inline emphasis in body paragraphs,
    not as section headings.

    Args:
        size: Font size in points.
        bold: Whether the span is bold.

    Returns:
        1, 2, or None (body text / inline bold).
    """
    if size >= 38:
        return 1  # document title
    if size >= 22 and bold:
        return 1  # major section headings (e.g. chapter titles)
    if size >= 20 and bold:
        return 2  # sub-section headings (e.g. "KEY IDEA")
    # 18 pt bold → inline bold inside a paragraph, NOT a heading
    return None


# ---------------------------------------------------------------------------
# Inline formatting
# ---------------------------------------------------------------------------

def _join_with_spaces(raw_texts: list[str]) -> str:
    """Join text fragments, inserting a space at line-wrap boundaries.

    Canva PDFs often split a single wrapped paragraph across many spans
    without including the space that the line break implies.  This function
    adds that space when neither adjacent fragment carries whitespace at
    the join point.

    Args:
        raw_texts: Ordered list of raw text strings from PDF spans.

    Returns:
        A single joined string.
    """
    parts: list[str] = []
    for raw in raw_texts:
        if parts:
            prev = parts[-1]
            # Insert a space if neither side of the join has whitespace
            # and the previous fragment does not end with a soft hyphen.
            if (
                prev
                and raw
                and not prev[-1].isspace()
                and not raw[0].isspace()
                and not prev.endswith("-")
            ):
                parts.append(" ")
        parts.append(raw)
    return "".join(parts).strip()


def spans_to_inline(spans: list[Span], apply_style: bool = True) -> str:
    """Convert a list of same-style spans to an inline Markdown string.

    All spans in the list are expected to share the same bold/italic state
    (enforced by the caller's style-grouping).  The entire joined text is
    wrapped in a single set of Markdown markers rather than wrapping each
    span individually, avoiding artefacts like ``**word1** **word2**``.

    Args:
        spans: Ordered list of Span objects that share a common style.
        apply_style: When False, bold/italic markers are not added. Use
            False for heading text, where Markdown heading syntax already
            provides visual weight.

    Returns:
        A single Markdown-formatted string.
    """
    if not spans:
        return ""

    text = _join_with_spaces([s.text for s in spans])
    if not text:
        return ""

    if not apply_style:
        return text

    bold   = is_bold(spans[0])
    italic = is_italic(spans[0])

    if bold and italic:
        return f"***{text}***"
    if bold:
        return f"**{text}**"
    if italic:
        return f"*{text}*"
    return text


# ---------------------------------------------------------------------------
# Implicit list detection
# ---------------------------------------------------------------------------

_IMPLICIT_LIST_MIN_ITEMS: int = 3   # need at least this many spans
_IMPLICIT_LIST_MAX_CHARS: int = 40  # each span text must be this short


def is_implicit_list(spans: list[Span]) -> bool:
    """Return True when a group of spans looks like a vertical bullet list.

    Canva PDFs sometimes place each list item at 18 pt (above the normal
    list-size threshold) stacked in a single block.  When a group has at
    least three short single-line spans with no terminal punctuation on the
    interior items, it is treated as an unordered list.

    Args:
        spans: A style-group of spans from the same block.

    Returns:
        True when the spans are better rendered as list items.
    """
    if len(spans) < _IMPLICIT_LIST_MIN_ITEMS:
        return False
    return all(len(s.text.strip()) <= _IMPLICIT_LIST_MAX_CHARS for s in spans)


# ---------------------------------------------------------------------------
# Post-processing
# ---------------------------------------------------------------------------

def _is_likely_list_item(text: str, max_chars: int = 40) -> bool:
    """Return True when text looks like a bullet list item.

    Criteria: short enough, no terminal sentence punctuation, and not a
    Markdown bold/italic styled block (which indicates a subsection header
    rather than a list entry).

    Args:
        text: The candidate text string.
        max_chars: Upper bound on text length.

    Returns:
        True when the text is a plausible list item.
    """
    if len(text) > max_chars:
        return False
    if text and text[-1] in ".!?;:":
        return False
    if text.startswith("*"):  # bold/italic Markdown marker
        return False
    if text.startswith("(") and text.endswith(")"):  # parenthetical section label
        return False
    return True


def apply_colon_intro_lists(
    tokens: list[tuple[str, str]],
    max_item_chars: int = 40,
) -> list[tuple[str, str]]:
    """Convert body tokens that follow a colon-ending intro sentence to list items.

    In PDFs generated by tools like Canva, list items at body-text size are
    placed in separate blocks immediately after an intro sentence that ends
    with ``:``.  This pass detects those runs and re-tags them as list items.

    Args:
        tokens: List of (kind, text) tuples.
        max_item_chars: Maximum text length for a candidate list item.

    Returns:
        A new list with detected list items re-tagged as 'list'.
    """
    result: list[tuple[str, str]] = []
    in_colon_list = False

    for kind, text in tokens:
        if kind == "body":
            if in_colon_list and _is_likely_list_item(text, max_item_chars):
                result.append(("list", text))
            else:
                if in_colon_list:
                    in_colon_list = False  # non-list item breaks the run
                result.append((kind, text))
                # A body token ending with ':' opens a new list context
                if text.endswith(":"):
                    in_colon_list = True
        elif kind in ("h1", "h2"):
            in_colon_list = False
            result.append((kind, text))
        else:
            # Existing list tokens do not break the colon-list context
            result.append((kind, text))

    return result


def merge_split_headings(tokens: list[tuple[str, str]]) -> list[tuple[str, str]]:
    """Merge consecutive headings of the same level into one entry.

    In design-tool PDFs (Canva etc.) a long heading is often placed as two
    separate text boxes, producing two consecutive same-level headings.
    This pass joins them with a space.

    Only merges when both entries share the same heading level AND the
    previous entry does not end with terminal punctuation (indicating the
    first is an incomplete phrase, not an intentional standalone heading).

    Args:
        tokens: List of (kind, text) tuples where kind is one of
                'h1', 'h2', 'body', 'list', or 'blank'.

    Returns:
        A new list with split headings merged.
    """
    result: list[tuple[str, str]] = []
    for kind, text in tokens:
        if (
            result
            and result[-1][0] == kind
            and kind in ("h1", "h2")
            and not re.search(r"[.!?:;]$", result[-1][1])
        ):
            result[-1] = (kind, result[-1][1] + " " + text)
        else:
            result.append((kind, text))
    return result


# ---------------------------------------------------------------------------
# Main conversion
# ---------------------------------------------------------------------------

def convert(doc: fitz.Document, *, list_size_threshold: float = 17.0) -> str:
    """Convert a PyMuPDF Document to a Markdown string.

    Args:
        doc: An open PyMuPDF Document.
        list_size_threshold: Spans with size strictly below this value (and
            no heading classification) are treated as list items when they
            appear as short standalone lines.

    Returns:
        A Markdown-formatted string.
    """
    blocks = extract_blocks(doc)
    # Collect output as (kind, text) tuples for easier post-processing.
    # kinds: 'h1', 'h2', 'body', 'list'
    tokens: list[tuple[str, str]] = []

    for block in blocks:
        if is_page_number_block(block):
            continue

        clean_spans = [s for s in block.spans if not is_noise(s)]
        if not clean_spans:
            continue

        # Group consecutive spans that share the same (size, bold) style.
        by_style: list[list[Span]] = []
        current_group: list[Span] = []
        current_size: float | None = None
        current_bold: bool | None = None

        for span in clean_spans:
            bold = is_bold(span)
            if current_size is None:
                current_size, current_bold = span.size, bold
            if span.size != current_size or bold != current_bold:
                if current_group:
                    by_style.append(current_group)
                current_group = []
                current_size, current_bold = span.size, bold
            current_group.append(span)
        if current_group:
            by_style.append(current_group)

        for group in by_style:
            dominant = group[0]
            level = classify_heading_level(dominant.size, is_bold(dominant))

            if level is not None:
                # Headings do not need bold/italic markers — the heading
                # syntax already provides visual weight.
                inline = spans_to_inline(group, apply_style=False)
                if inline:
                    tokens.append(("h1" if level == 1 else "h2", inline))
            elif dominant.size < list_size_threshold:
                inline = spans_to_inline(group)
                if inline:
                    tokens.append(("list", inline))
            elif is_implicit_list(group):
                # Multiple very short co-located spans → individual list items
                for span in group:
                    item = span.text.strip()
                    if item:
                        tokens.append(("list", item))
            else:
                inline = spans_to_inline(group)
                if inline:
                    tokens.append(("body", inline))

    # Merge wrapped heading titles (e.g. two consecutive H1s from one visual title)
    tokens = merge_split_headings(tokens)
    # Convert body tokens that follow a colon-ending intro to list items
    tokens = apply_colon_intro_lists(tokens)

    # Render tokens to Markdown lines
    lines: list[str] = []
    in_list = False

    for kind, text in tokens:
        if kind == "h1":
            if in_list:
                lines.append("")
                in_list = False
            lines.append("")
            lines.append(f"# {text}")
        elif kind == "h2":
            if in_list:
                lines.append("")
                in_list = False
            lines.append("")
            lines.append(f"## {text}")
        elif kind == "list":
            in_list = True
            lines.append(f"- {text}")
        else:  # body
            if in_list:
                lines.append("")
                in_list = False
            lines.append("")
            lines.append(text)

    if in_list:
        lines.append("")

    # Strip leading blank lines and normalise to one blank line between blocks
    text = "\n".join(lines).strip()
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text + "\n"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    """Build and return the argument parser.

    Returns:
        Configured ArgumentParser instance.
    """
    parser = argparse.ArgumentParser(
        prog="pdf2md",
        description=(
            "Convert a PDF file to Markdown. Preserves headings, paragraphs, "
            "lists, and inline bold/italic. Requires pymupdf (pip install pymupdf)."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  pdf2md document.pdf\n"
            "  pdf2md document.pdf output.md\n"
            "  pdf2md --stdout document.pdf\n"
            "  pdf2md --list-size 16 document.pdf output.md\n"
        ),
    )
    parser.add_argument(
        "input",
        metavar="input.pdf",
        help="Path to the input PDF file.",
    )
    parser.add_argument(
        "output",
        metavar="output.md",
        nargs="?",
        help=(
            "Path to write the Markdown output. "
            "Defaults to the input filename with a .md extension."
        ),
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Write output to stdout instead of a file.",
    )
    parser.add_argument(
        "--list-size",
        type=float,
        default=17.0,
        metavar="PT",
        help=(
            "Font size threshold (points) below which short lines are treated "
            "as list items. Default: 17.0"
        ),
    )
    return parser


def main() -> None:
    """Entry point for the pdf2md command.

    Parses arguments, opens the PDF, converts it, and writes the result.

    Example:
        $ python3 pdf2md.py input.pdf output.md
    """
    parser = build_parser()
    args = parser.parse_args()

    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        sys.exit(1)
    if not input_path.is_file():
        print(f"Error: Not a file: {input_path}", file=sys.stderr)
        sys.exit(1)

    try:
        doc = fitz.open(str(input_path))
    except Exception as exc:
        print(f"Error: Could not open PDF: {exc}", file=sys.stderr)
        sys.exit(1)

    markdown = convert(doc, list_size_threshold=args.list_size)
    doc.close()

    if args.stdout:
        sys.stdout.write(markdown)
        return

    if args.output:
        output_path = Path(args.output).expanduser().resolve()
    else:
        output_path = input_path.with_suffix(".md")

    try:
        output_path.write_text(markdown, encoding="utf-8")
    except OSError as exc:
        print(f"Error: Could not write output: {exc}", file=sys.stderr)
        sys.exit(1)

    print(f"Written: {output_path}")


if __name__ == "__main__":
    main()
