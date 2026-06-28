import os
import re

def verify_rules():
    lib_dir = "/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/lib"
    rule_22_violations = []
    rule_32_violations = []
    
    # Rule 22: No const widgets referencing AppColors
    # We look for 'const' followed by some widget constructors (e.g. Text, Icon, TextStyle, etc.)
    # that reference AppColors.
    # A generic regex for "const [A-Za-z0-9_]+\((?:[^)]|\n)*AppColors\." 
    # since anything within a const expression is part of the const context.
    # Note that Dart parser would throw a compile error if it's invalid, but we also want to ensure
    # there is no 'const' keyword preceding any widget initialization that uses AppColors.
    
    # Rule 32: No raw "mounted". Every "mounted" must be preceded by "context." (excluding the definition of State.mounted itself if we subclass it, but we are inside lib, so mostly we just use context.mounted).
    
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # 1. Search for raw 'mounted'
                # Find all occurrences of 'mounted'
                for match in re.finditer(r'\bmounted\b', content):
                    start = match.start()
                    # Check if preceded by 'context.'
                    preceding = content[max(0, start - 8):start]
                    if not preceding.endswith('context.'):
                        # Make sure it's not a comment line or a string literal or part of the framework itself
                        # We can extract the line
                        line_start = content.rfind('\n', 0, start) + 1
                        line_end = content.find('\n', start)
                        line = content[line_start:line_end].strip()
                        if not line.startswith('//') and not line.startswith('*'):
                            rule_32_violations.append((file_path, line))
                            
                # 2. Search for const context referencing AppColors
                # We search for lines containing 'const' and 'AppColors' (on the same line or in multi-line blocks)
                # Let's check if 'const' is present on the same line or preceding lines that declare a widget.
                # A simple heuristic: check for lines containing both 'const' and 'AppColors'
                lines = content.splitlines()
                for i, line in enumerate(lines):
                    if 'const' in line and 'AppColors' in line:
                        rule_22_violations.append((file_path, i + 1, line))
                    # Also check if a line has 'AppColors' and the preceding few lines have an open 'const WidgetName('
                    if 'AppColors' in line:
                        # Scan back up to 5 lines to see if there is a 'const' that hasn't been closed
                        context_block = "\n".join(lines[max(0, i-5):i+1])
                        # If there is 'const' in the block, check if it's a const constructor
                        # e.g., "const TextStyle" or "const Icon"
                        # We look for a line starting with 'const ' followed by an uppercase word (Widget)
                        if re.search(r'\bconst\s+[A-Z][A-Za-z0-9_]*\(', context_block):
                            rule_22_violations.append((file_path, i + 1, f"Possible const widget block:\n{context_block}"))

    print("=== Rule 32 (Raw mounted) Violations ===")
    if rule_32_violations:
        for file, line in rule_32_violations:
            print(f"{file}: {line}")
    else:
        print("None found!")
        
    print("\n=== Rule 22 (Const AppColors) Violations ===")
    if rule_22_violations:
        for file, line_num, line in rule_22_violations:
            print(f"{file}:{line_num}: {line}")
    else:
        print("None found!")

if __name__ == "__main__":
    verify_rules()
