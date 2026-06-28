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

print(f"Scanning {len(dart_files)} Dart files for mounted...")

violations = []

for file_path in dart_files:
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # We want to find occurrences of 'mounted' that are not preceded by 'context.'
    # We should exclude comments and string literals if possible, but let's do a regex search first.
    # Look for 'mounted' word boundary, but NOT 'context.mounted'
    # Match: (?<!context\.)\bmounted\b
    matches = re.finditer(r'(?<!context\.)\bmounted\b', content)
    for match in matches:
        # Get line number and line content
        start_pos = match.start()
        # Find line number
        line_num = content.count('\n', 0, start_pos) + 1
        # Find line content
        line_start = content.rfind('\n', 0, start_pos) + 1
        line_end = content.find('\n', start_pos)
        if line_end == -1:
            line_end = len(content)
        line_content = content[line_start:line_end].strip()
        
        # Filter out comments
        if line_content.startswith('//') or line_content.startswith('*'):
            continue
            
        violations.append((file_path, line_num, line_content))

print(f"Found {len(violations)} raw mounted violations:")
for file_path, line_num, snippet in violations:
    print(f"{file_path}:{line_num}: {snippet}")
