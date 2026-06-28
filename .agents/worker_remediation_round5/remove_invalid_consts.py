import re
from collections import defaultdict

def main():
    log_path = '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/worker_remediation_round5/analyze_output.txt'
    with open(log_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find error matches
    # e.g., error • Invalid constant value • lib/core/presentation/app_shell.dart:85:70 • invalid_constant
    # or: error • Arguments of a constant creation must be constant expressions. • lib/features/alarms/presentation/wizard/alarm_wizard_screen.dart:100:65 • const_with_non_constant_argument
    pattern = re.compile(r'error • (?:Invalid constant value|Arguments of a constant creation must be constant expressions[^\n•]*|The constructor being called isn\'t a const constructor[^\n•]*) • ([^\s:]+):(\d+):(\d+)')
    matches = pattern.findall(content)
    
    if not matches:
        print("No invalid constant errors found.")
        return

    print(f"Parsed {len(matches)} error locations.")

    # Group by file to minimize I/O
    file_errors = defaultdict(list)
    for file_path, line_str, col_str in matches:
        file_errors[file_path].append(int(line_str))

    for file_path, line_numbers in file_errors.items():
        # Sort line numbers in descending order
        unique_lines = sorted(list(set(line_numbers)), reverse=True)
        print(f"\nProcessing file: {file_path}")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except Exception as e:
            print(f"  Error reading file {file_path}: {e}")
            continue

        modified = False
        for l_num in unique_lines:
            # We look upwards from the error line
            start_idx = l_num - 1
            found = False
            for idx in range(start_idx, max(-1, start_idx - 15), -1):
                if idx >= len(lines):
                    continue
                line = lines[idx]
                # Look for 'const ' with word boundaries
                if re.search(r'\bconst\b', line):
                    # Replace first occurrence of const
                    new_line = re.sub(r'\bconst\s+', '', line, count=1)
                    if new_line != line:
                        lines[idx] = new_line
                        print(f"  Removed 'const' on line {idx + 1} (error on line {l_num}):")
                        print(f"    Old: {line.strip()}")
                        print(f"    New: {new_line.strip()}")
                        found = True
                        modified = True
                        break
            if not found:
                print(f"  Warning: Could not find 'const' keyword upwards from line {l_num}")

        if modified:
            try:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(lines)
                print(f"  Saved changes to {file_path}")
            except Exception as e:
                print(f"  Error writing file {file_path}: {e}")

if __name__ == '__main__':
    main()
