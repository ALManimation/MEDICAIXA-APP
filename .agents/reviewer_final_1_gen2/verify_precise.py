import os
import re

def find_const_blocks(content):
    violations = []
    # Find all occurrences of the word 'const'
    for match in re.finditer(r'\bconst\s+', content):
        start_idx = match.start()
        # Find where the expression ends.
        # We track nesting of (), [], {}
        # Also commas and semicolons at nesting level 0.
        nesting = []
        end_idx = start_idx
        # Skip the 'const' keyword
        idx = match.end()
        
        while idx < len(content):
            char = content[idx]
            if char in '([{':
                nesting.append(char)
            elif char in ')]}':
                if not nesting:
                    # Closing bracket outside nesting? Stop.
                    end_idx = idx
                    break
                # Pop corresponding opening
                last = nesting.pop()
                if (char == ')' and last != '(') or (char == ']' and last != '[') or (char == '}' and last != '{'):
                    # Mismatched bracket (shouldn't happen in valid dart, but stop anyway)
                    end_idx = idx
                    break
            elif char in ',;':
                if not nesting:
                    # Comma or semicolon at root of const expression (e.g. const X(), or const X, )
                    end_idx = idx
                    break
            idx += 1
        else:
            end_idx = len(content)
            
        block = content[start_idx:end_idx]
        if 'AppColors' in block:
            violations.append((start_idx, end_idx, block))
            
    return violations

def check_all_files():
    lib_dir = "/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/lib"
    all_violations = []
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Strip single-line comments and multi-line comments to avoid false positives
                # in commented out code or documentation.
                # Replace comments with spaces to preserve indices
                def comment_replacer(match):
                    return ' ' * len(match.group(0))
                
                content_clean = re.sub(r'//.*', comment_replacer, content)
                content_clean = re.sub(r'/\*.*?\*/', comment_replacer, content_clean, flags=re.DOTALL)
                
                violations = find_const_blocks(content_clean)
                for start, end, block in violations:
                    # Get line number
                    line_num = content[:start].count('\n') + 1
                    all_violations.append((file_path, line_num, block.strip()))
                    
    if all_violations:
        print(f"Found {len(all_violations)} violations of Rule 22:")
        for path, line, block in all_violations:
            print(f"\nFile: {path}:{line}")
            print("--- Block ---")
            print(block)
            print("-------------")
    else:
        print("Rule 22 check: 100% compliant! No AppColors found in const contexts.")

if __name__ == "__main__":
    check_all_files()
