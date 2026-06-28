import os
import re

root_dir = "/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app"
dart_files = []

for root, dirs, files in os.walk(root_dir):
    if ".agents" in root or ".git" in root or ".dart_tool" in root or "build" in root:
        continue
    for file in files:
        if file.endswith(".dart"):
            dart_files.append(os.path.join(root, file))

print(f"Scanning {len(dart_files)} Dart files...")

# Pattern to match 'const' followed by some characters and AppColors.
# Since Dart const can span multiple lines, we can match block by block or line-by-line.
# First, let's do a simple check.
violations = []

for file_path in dart_files:
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # We want to find cases of 'const' followed by something containing 'AppColors' before the matching closing parenthesis/bracket or before the next statement.
    # A simple regex approach: search for 'const' and see if 'AppColors' is within the constructor call.
    # To be very precise, let's search for 'const ' and trace the scope, or search for 'const' and 'AppColors' on the same line first, or within a small window.
    # Let's search for 'const' and check if 'AppColors' is on the same line, or the next few lines.
    lines = content.splitlines()
    for idx, line in enumerate(lines):
        if "const " in line and "AppColors." in line:
            violations.append((file_path, idx + 1, line.strip()))
        # Let's also look for multi-line cases. e.g. const BorderSide(\n  color: AppColors.border
        # Let's check if a line has 'const' and subsequent lines (up to 5 lines) have 'AppColors' before any other 'const' or ';'
        elif "const " in line:
            # check next 4 lines
            for offset in range(1, 5):
                if idx + offset < len(lines):
                    next_line = lines[idx + offset]
                    if "AppColors." in next_line:
                        # check if there's a ';' or another 'const' in between
                        in_between = "".join(lines[idx+1 : idx+offset])
                        if ";" not in in_between and "const " not in in_between:
                            violations.append((file_path, idx + 1, f"{line.strip()} ... {next_line.strip()}"))
                            break

print(f"Found {len(violations)} potential violations:")
for file_path, line_num, snippet in violations:
    print(f"{file_path}:{line_num}: {snippet}")
