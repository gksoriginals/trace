"""Redact secrets from skill-written text. Recipes stay explanatory, never secret-bearing."""

from __future__ import annotations

import re

# Patterns are deliberately narrow: known token shapes and common env assignment forms.
_PATTERNS = (
    re.compile(r"\bsk-[A-Za-z0-9_-]{8,}\b"),
    re.compile(r"\bghp_[A-Za-z0-9]{20,}\b"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"),
    re.compile(r"(?i)\b(api[_-]?key|token|password|secret)\s*[:=]\s*\S+"),
    re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._\-]+"),
)


def redact_text(text: str) -> str:
    if not text:
        return text
    redacted = text
    for pattern in _PATTERNS:
        redacted = pattern.sub("[redacted]", redacted)
    return redacted
