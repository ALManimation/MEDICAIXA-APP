import os
import re

def find_context_after_await(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Strip comments
    clean_content = re.sub(r'//.*', '', content)
    clean_content = re.sub(r'/\*.*?\*/', '', clean_content, flags=re.DOTALL)
    
    # We want to find method blocks. Since parsing Dart fully with regex is hard,
    # let's look for functions or blocks that have 'async' and contain 'await'.
    # A simple line-by-line or method-by-method scanner.
    # Let's search for 'await' and then check if 'context' is used subsequently
    # without a 'context.mounted' check.
    
    # Let's find all matches of 'await'
    pattern_await = re.compile(r'\bawait\b')
    violations = []
    
    # Let's split by methods roughly, or just look at lines.
    # If a file has 'await', let's print lines with 'context' after the first 'await'.
    # We can refine this: for each file, find all 'await'.
    # If there are none, skip.
    await_matches = list(pattern_await.finditer(clean_content))
    if not await_matches:
        return []
        
    lines = content.splitlines()
    # Let's find all occurrences of 'context' (but not 'context.mounted')
    # and see if they occur after an 'await' in the code.
    # To be precise, let's look for async methods.
    # A method starts with something like `async {` or similar.
    # Let's just find any 'context' usage (like 'Navigator.of(context)' or 'ScaffoldMessenger.of(context)'
    # or 'Navigator.push(context') that appears after an 'await' within some range.
    for i, line in enumerate(lines):
        if 'context' in line and not 'context.mounted' in line:
            # Look back to see if there was an 'await' recently, and if there is a 'context.mounted' check in between.
            # Let's look back up to 30 lines
            has_await = False
            has_mounted_check = False
            for j in range(max(0, i - 30), i):
                prev_line = lines[j]
                if 'await' in prev_line:
                    has_await = True
                if 'context.mounted' in prev_line or 'mounted' in prev_line:
                    has_mounted_check = True
            if has_await and not has_mounted_check:
                # Potential violation! Let's record it.
                violations.append((i + 1, line.strip()))
                
    return violations

def main():
    lib_dir = '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/lib'
    all_violations = {}
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                v = find_context_after_await(filepath)
                if v:
                    all_violations[filepath] = v
                    
    total = 0
    print("Potential Rule 32 violations (context after await without mounted check):")
    for filepath, v_list in all_violations.items():
        print(f"\nFile: {filepath}")
        for line_num, line_text in v_list:
            total += 1
            print(f"Line {line_num}: {line_text}")
    print(f"\nTotal potential violations: {total}")

if __name__ == '__main__':
    main()
