# Rule 12 Scan Skill

Verify that all functions are under 50 lines.
Scan modified files before committing.

## Usage

```bash
# Count lines per function in a Python file
grep -n "def " <file> | while read line; do echo "$line"; done
```
