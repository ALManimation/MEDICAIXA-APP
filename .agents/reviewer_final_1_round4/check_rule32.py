import os
import re

def check_plain_mounted(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # We want to find any word 'mounted' that is not preceded by 'context.'
    # But wait, we should also ignore comments and string literals if possible.
    # A simple regex can find 'mounted' and check its prefix.
    # Let's search for the pattern.
    pattern = re.compile(r'\bmounted\b')
    violations = []
    
    # Strip comments first
    clean_content = re.sub(r'//.*', '', content)
    clean_content = re.sub(r'/\*.*?\*/', '', clean_content, flags=re.DOTALL)
    
    for match in pattern.finditer(clean_content):
        start = match.start()
        # Find line number in original content
        line_num = content.count('\n', 0, start) + 1
        
        # Check if the prefix is 'context.'
        # Let's look back from 'start'
        prefix = clean_content[max(0, start - 8):start]
        if not prefix.endswith('context.'):
            # Report violation
            # Let's get the line content
            line_start = clean_content.rfind('\n', 0, start) + 1
            line_end = clean_content.find('\n', start)
            if line_end == -1:
                line_end = len(clean_content)
            line_text = clean_content[line_start:line_end].strip()
            violations.append((line_num, line_text))
            
    return violations

def main():
    lib_dir = '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/lib'
    all_violations = {}
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                v = check_plain_mounted(filepath)
                if v:
                    all_violations[filepath] = v
                    
    total = 0
    print("Rule 32 (Plain 'mounted') Violations:")
    for filepath, v_list in all_violations.items():
        print(f"\nFile: {filepath}")
        for line_num, line_text in v_list:
            total += 1
            print(f"Line {line_num}: {line_text}")
    print(f"\nTotal violations: {total}")

if __name__ == '__main__':
    main()
