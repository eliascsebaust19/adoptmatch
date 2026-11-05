# AdoptMatch Agent Guidelines & Writing Standards (Unslop)

This project strictly follows the **Unslop** writing and engineering principles. All generated prose, documentation, code comments, and in-app copy must sound natural, human, and direct.

---

## ✍️ Unslop Writing Standards

### 1. Zero AI Slop & Buzzwords
Never use robotic AI idioms, corporate buzzwords, or artificial enthusiasm. Specifically avoid:
- **Empty Openers**: "Here's the thing:", "Certainly!", "Let that sink in", "In today's fast-paced landscape", "Delve into", "A testament to".
- **Robotic Fillers**: "Moreover", "Furthermore", "In conclusion", "It is important to remember", "Tapestry", "Crucial".
- **Inflated Corporate Claims**: Avoid "revolutionary paradigm-shifting ecosystem engineered with cutting-edge capabilities". Say plainly what the software does.

### 2. Tone & Voice Guidelines
- **Technical & Documentation (`crisp` preset)**:
  - Short, clear, direct sentences.
  - Active voice with precise verbs.
  - Plain, accurate technical explanations without unnecessary marketing fluff.
- **In-App Copy & Chat Companion (`warm` preset)**:
  - Friendly, conversational, and genuinely helpful.
  - Avoid canned or repetitive scripted replies.
  - Empathize naturally with adopters and pet parents in English, Bengali, or Banglish.

### 3. Core Rewrite Contract
- **Preserve Facts & Truth**: Never alter technical specs, ports, routes, credentials, or architectural boundaries while de-slopping.
- **Minimal Edits**: Repair defective or formulaic sentences; leave clean technical text intact.
- **No Staccato**: Do not overcorrect into choppy, robotic fragments—maintain natural sentence rhythm.

---

## 🛠️ Project Skills & Workflows
- **`unslop` Skill**: Located at `.agent/skills/unslop`. Use for auditing text (`/unslop cleanup`), rewriting copy (`/unslop rewrite`), or running offline phrase scanners (`scripts/banned_phrase_scan.py`).
- **`flutter-pro-upgrade` Skill**: Located at `.agent/skills/flutter-pro-upgrade`. Use for UI polish and role-based architecture enhancements.

