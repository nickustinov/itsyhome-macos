#!/usr/bin/env python3
"""
Extract information from HomeKit Accessory Protocol specification.

Usage:
    ./hap-spec.py --service <name>         # Look up a service definition
    ./hap-spec.py --char <name>            # Look up a characteristic definition
    ./hap-spec.py --list-services          # List all services
    ./hap-spec.py --list-characteristics   # List all characteristics
    ./hap-spec.py <search_term>            # General search

Examples:
    ./hap-spec.py --service Lightbulb
    ./hap-spec.py --service "Light Bulb"
    ./hap-spec.py --char Brightness
    ./hap-spec.py --char "On"
    ./hap-spec.py "Active"
"""

import sys
import re
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SPEC_FILE = os.path.join(SCRIPT_DIR, "homekit-spec.md")


class HAPSpec:
    """Query the HomeKit Accessory Protocol specification."""

    def __init__(self, spec_file=SPEC_FILE):
        self.spec_file = spec_file
        self.content = ""
        self.lines = []
        self._load()

    def _load(self):
        """Load the markdown file."""
        with open(self.spec_file, "r", encoding="utf-8") as f:
            self.content = f.read()
            self.lines = self.content.split("\n")

    def _find_section(self, pattern, start_line=0):
        """Find a section by header pattern, return (start_line, end_line)."""
        start = None
        for i in range(start_line, len(self.lines)):
            line = self.lines[i]
            if re.match(pattern, line):
                start = i
                break

        if start is None:
            return None, None

        # Find the end (next section header at same or higher level)
        header_match = re.match(r"^(#+)", self.lines[start])
        header_level = len(header_match.group(1)) if header_match else 5

        end = len(self.lines)
        for i in range(start + 1, len(self.lines)):
            line = self.lines[i]
            match = re.match(r"^(#+)\s", line)
            if match and len(match.group(1)) <= header_level:
                end = i
                break

        return start, end

    def _extract_section(self, start, end):
        """Extract and clean a section."""
        if start is None:
            return None

        lines = self.lines[start:end]
        # Remove page numbers, copyright lines, and chapter headers
        cleaned = []
        for line in lines:
            # Skip standalone page numbers
            if re.match(r"^\d+\s*$", line.strip()):
                continue
            # Skip copyright lines
            if "Copyright ©" in line:
                continue
            # Skip chapter header lines like "8. Apple-defined Services"
            if re.match(r"^\d+\.\s+Apple-defined\s+(Services|Characteristics)\s*$", line.strip()):
                continue
            cleaned.append(line)

        # Remove excessive blank lines
        result = []
        prev_blank = False
        for line in cleaned:
            is_blank = line.strip() == ""
            if is_blank and prev_blank:
                continue
            result.append(line)
            prev_blank = is_blank

        return "\n".join(result).strip()

    def _normalize_name(self, name):
        """Normalize service/characteristic name for matching."""
        # "Lightbulb" -> "light bulb", "AirPurifier" -> "air purifier"
        spaced = re.sub(r"([a-z])([A-Z])", r"\1 \2", name)
        return spaced.lower().strip()

    def _names_match(self, search_name, line_name):
        """Check if names match, handling variations like Lightbulb vs Light Bulb."""
        search_norm = self._normalize_name(search_name)
        line_norm = self._normalize_name(line_name)

        # Direct match
        if search_norm == line_norm:
            return True

        # Match without spaces (lightbulb == light bulb)
        if search_norm.replace(" ", "") == line_norm.replace(" ", ""):
            return True

        # Substring match
        if search_norm in line_norm or line_norm in search_norm:
            return True

        return False

    def get_service(self, name):
        """Get a service definition by name."""
        # Try exact match first
        pattern = rf"^#####\s+8\.\d+\s+{re.escape(name)}\s*$"
        start, end = self._find_section(pattern)

        # Try flexible name matching
        if start is None:
            for i, line in enumerate(self.lines):
                match = re.match(r"^#####\s+8\.\d+\s+(.+)$", line)
                if match:
                    line_name = match.group(1).strip()
                    if self._names_match(name, line_name):
                        start, end = self._find_section(r"^#####", i)
                        break

        if start is None:
            return None

        section = self._extract_section(start, end)

        # Follow referenced characteristics
        references = self._extract_references(section)

        return {"content": section, "references": references}

    def get_characteristic(self, name):
        """Get a characteristic definition by name."""
        # Try exact match first
        pattern = rf"^#####\s+9\.\d+\s+{re.escape(name)}\s*$"
        start, end = self._find_section(pattern)

        # Try flexible name matching
        if start is None:
            for i, line in enumerate(self.lines):
                match = re.match(r"^#####\s+9\.\d+\s+(.+)$", line)
                if match:
                    line_name = match.group(1).strip()
                    if self._names_match(name, line_name):
                        start, end = self._find_section(r"^#####", i)
                        break

        if start is None:
            return None

        section = self._extract_section(start, end)
        references = self._extract_references(section)

        return {"content": section, "references": references}

    def _extract_references(self, content):
        """Extract referenced sections from content."""
        if not content:
            return {}

        references = {}
        # Find references like "9.3 Active" or "8.18 Heater Cooler"
        # Handle both ASCII quotes and Unicode smart quotes (U+201C/U+201D)
        matches = re.findall(r'["\u201c\u201d](\d+\.\d+)\s+([^"\u201c\u201d]+)["\u201c\u201d]', content)

        for section_num, section_name in matches:
            key = f"{section_num} {section_name}"
            if key in references:
                continue

            # Look up the referenced section
            if section_num.startswith("8."):
                pattern = rf"^#####\s+{re.escape(section_num)}\s+"
            else:
                pattern = rf"^#####\s+{re.escape(section_num)}\s+"

            start, end = self._find_section(pattern)
            if start is not None:
                # Get a brief excerpt (first ~15 lines after header)
                excerpt_end = min(end, start + 20)
                excerpt = self._extract_section(start, excerpt_end)
                references[key] = excerpt

        return references

    def search(self, term):
        """Search for a term in the spec."""
        results = []
        term_lower = term.lower()

        i = 0
        while i < len(self.lines):
            line = self.lines[i]
            if term_lower in line.lower():
                # Find the containing section
                section_start = i
                for j in range(i, -1, -1):
                    if re.match(r"^#####\s+\d+\.\d+\s+", self.lines[j]):
                        section_start = j
                        break

                # Get context (10 lines before and after match within section)
                context_start = max(section_start, i - 5)
                context_end = min(len(self.lines), i + 10)

                context = "\n".join(self.lines[context_start:context_end])
                header = self.lines[section_start] if section_start != i else ""

                results.append({
                    "line": i + 1,
                    "header": header,
                    "match": line.strip(),
                    "context": context,
                })

                # Skip ahead to avoid duplicate matches in same area
                i = context_end
            else:
                i += 1

        return results

    def list_services(self):
        """List all services defined in chapter 8."""
        services = []
        pattern = re.compile(r"^#####\s+(8\.(\d+))\s+(.+)$")

        for line in self.lines:
            match = pattern.match(line)
            if match:
                services.append({
                    "number": match.group(1),
                    "sort_key": int(match.group(2)),
                    "name": match.group(3).strip(),
                })

        services.sort(key=lambda x: x["sort_key"])
        return services

    def list_characteristics(self):
        """List all characteristics defined in chapter 9."""
        chars = []
        pattern = re.compile(r"^#####\s+(9\.(\d+))\s+(.+)$")

        for line in self.lines:
            match = pattern.match(line)
            if match:
                # Skip "9.1 Overview"
                if match.group(2) == "1" and "Overview" in match.group(3):
                    continue
                chars.append({
                    "number": match.group(1),
                    "sort_key": int(match.group(2)),
                    "name": match.group(3).strip(),
                })

        chars.sort(key=lambda x: x["sort_key"])
        return chars


def print_result(name, result, result_type):
    """Print a service or characteristic result."""
    print(f"\n### {result_type}: {name}")
    print("=" * 60)
    print(result["content"])

    if result.get("references"):
        print("\n" + "=" * 60)
        print("### Referenced sections")
        print("=" * 60)
        for key, excerpt in result["references"].items():
            print(f"\n--- {key} ---")
            print(excerpt)
            print()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    arg = sys.argv[1]
    spec = HAPSpec()

    if arg == "--list-services":
        services = spec.list_services()
        print(f"Found {len(services)} services:\n")
        for s in services:
            print(f"  {s['number']}: {s['name']}")
        return

    if arg == "--list-characteristics":
        chars = spec.list_characteristics()
        print(f"Found {len(chars)} characteristics:\n")
        for c in chars:
            print(f"  {c['number']}: {c['name']}")
        return

    if arg == "--service" and len(sys.argv) >= 3:
        name = " ".join(sys.argv[2:])
        result = spec.get_service(name)
        if result:
            print_result(name, result, "Service")
        else:
            print(f"Service '{name}' not found")
            print("\nAvailable services:")
            for s in spec.list_services():
                if name.lower() in s["name"].lower():
                    print(f"  {s['number']}: {s['name']}")
        return

    if arg == "--char" and len(sys.argv) >= 3:
        name = " ".join(sys.argv[2:])
        result = spec.get_characteristic(name)
        if result:
            print_result(name, result, "Characteristic")
        else:
            print(f"Characteristic '{name}' not found")
            print("\nSimilar characteristics:")
            for c in spec.list_characteristics():
                if name.lower() in c["name"].lower():
                    print(f"  {c['number']}: {c['name']}")
        return

    # General search
    term = " ".join(sys.argv[1:])
    print(f"Searching for: {term}\n")
    print("=" * 60)

    results = spec.search(term)
    if not results:
        print(f"No results found for '{term}'")
        sys.exit(1)

    print(f"Found {len(results)} matches:\n")
    for i, r in enumerate(results[:10]):
        print(f"\n--- Match {i + 1} (line {r['line']}) ---")
        if r["header"]:
            print(f"Section: {r['header']}")
        print(r["context"])

    if len(results) > 10:
        print(f"\n... and {len(results) - 10} more matches")


if __name__ == "__main__":
    main()
