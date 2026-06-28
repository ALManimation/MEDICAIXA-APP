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

violations = []

for file_path in dart_files:
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    lines = content.splitlines()
    for idx, line in enumerate(lines):
        # Clean comment block
        cleaned_line = line.split("//")[0]
        if "const " in cleaned_line and "AppColors." in cleaned_line:
            violations.append((file_path, idx + 1, line.strip()))
        elif "const " in cleaned_line:
            # check if AppColors is used in subsequent lines belonging to this const declaration
            # look ahead up to 10 lines
            for offset in range(1, 10):
                if idx + offset < len(lines):
                    next_line = lines[idx + offset]
                    # check if next_line starts a new statement/const or closes the current constructor
                    # if there's a ';' or another 'const ' or a new widget starting, stop
                    cleaned_next = next_line.split("//")[0]
                    if "AppColors." in cleaned_next:
                        # make sure no closing semicolon or other const was in between
                        in_between = "".join(lines[idx+1 : idx+offset])
                        cleaned_in_between = "".join(l.split("//")[0] for l in lines[idx+1 : idx+offset])
                        if ";" not in cleaned_in_between and "const " not in cleaned_in_between:
                            violations.append((file_path, idx + 1, f"{line.strip()} ... {next_line.strip()}"))
                            break
                    if ";" in cleaned_next or "const " in cleaned_next:
                        break

output_file = "/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/reviewer_final_1_round5/violations.txt"
with open(output_file, "w", encoding="utf-8") as f:
    f.write(f"Found {len(violations)} potential Rule 22 violations:\n")
    for file_path, line_num, snippet in violations:
        # relative path
        rel_path = os.path.relpath(file_path, root_dir)
        f.write(f"{rel_path}:{line_num}: {snippet}\n")

print(f"Written {len(violations)} violations to {output_file}")
