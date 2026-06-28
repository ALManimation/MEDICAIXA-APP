import re
import os

def parse_violations(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # We parse the file and find matches of:
    # File: <filepath>
    # --- Block ---
    # <block content>
    # -------------
    # Let's do it using a regex or simple state machine since regex with lazy/greedy matching can be tricky.
    blocks = []
    current_file = None
    in_block = False
    block_lines = []
    
    for line in content.splitlines():
        if line.startswith('File: '):
            # Format is: File: /path/to/file.dart:line
            parts = line[6:].rsplit(':', 1)
            current_file = parts[0]
            # remove line number suffix if present
            if len(parts) > 1 and parts[1].isdigit():
                line_num = int(parts[1])
            else:
                line_num = 0
        elif line == '--- Block ---':
            in_block = True
            block_lines = []
        elif line == '-------------':
            in_block = False
            # Clean up line numbers in block lines
            cleaned_block_lines = []
            for bl in block_lines:
                # Remove "<line_num>: " prefix if present
                clean_bl = re.sub(r'^\d+:\s*', '', bl)
                cleaned_block_lines.append(clean_bl)
            blocks.append((current_file, line_num, "\n".join(cleaned_block_lines).strip()))
        elif in_block:
            block_lines.append(line)
            
    return blocks

def verify_resolved():
    violations_file = '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/reviewer_final_1_gen2/violations.txt'
    violations = parse_violations(violations_file)
    
    print(f"Parsed {len(violations)} violations from violations.txt.")
    
    resolved_count = 0
    unresolved = []
    
    for fp, line_num, original_block in violations:
        if not os.path.exists(fp):
            print(f"File {fp} no longer exists. Marked as resolved.")
            resolved_count += 1
            continue
            
        with open(fp, 'r', encoding='utf-8') as f:
            file_content = f.read()
            
        # Clean whitespaces for robust comparison
        clean_file_content = re.sub(r'\s+', ' ', file_content)
        clean_original_block = re.sub(r'\s+', ' ', original_block)
        
        # If the original block (with the 'const') is still present in the file:
        if clean_original_block in clean_file_content:
            unresolved.append((fp, line_num, original_block))
        else:
            resolved_count += 1
            
    print(f"\nVerification Results:")
    print(f"Resolved: {resolved_count}")
    print(f"Unresolved: {len(unresolved)}")
    for fp, line_num, block in unresolved:
        print(f"Unresolved violation at {fp}:{line_num}")
        print(block)
        print("-" * 30)

if __name__ == '__main__':
    verify_resolved()
