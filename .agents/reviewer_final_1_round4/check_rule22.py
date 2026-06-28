import os
import re

def find_matching_bracket(text, start_index):
    open_char = text[start_index]
    if open_char == '(':
        close_char = ')'
    elif open_char == '[':
        close_char = ']'
    elif open_char == '{':
        close_char = '}'
    else:
        return -1
        
    depth = 0
    for i in range(start_index, len(text)):
        char = text[i]
        if char == open_char:
            depth += 1
        elif char == close_char:
            depth -= 1
            if depth == 0:
                return i
    return -1

def scan_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    violations = []
    pattern = re.compile(r'\bconst\b')
    for match in pattern.finditer(content):
        start_pos = match.start()
        line_num = content.count('\n', 0, start_pos) + 1
        
        sub_text = content[start_pos:start_pos + 1000]
        delim_match = re.search(r'[\(\[\{]', sub_text)
        if not delim_match:
            continue
            
        open_pos_in_sub = delim_match.start()
        open_char = delim_match.group(0)
        open_pos = start_pos + open_pos_in_sub
        
        close_pos = find_matching_bracket(content, open_pos)
        if close_pos == -1:
            semicolon_pos = content.find(';', start_pos)
            if semicolon_pos != -1:
                block_content = content[start_pos:semicolon_pos]
            else:
                block_content = content[start_pos:start_pos+100]
        else:
            block_content = content[start_pos:close_pos+1]
            
        if 'AppColors' in block_content:
            stripped_block = re.sub(r'//.*', '', block_content)
            stripped_block = re.sub(r'/\*.*?\*/', '', stripped_block, flags=re.DOTALL)
            if 'AppColors' in stripped_block:
                violations.append((line_num, block_content.strip()))
                
    return violations

def main():
    lib_dir = '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/lib'
    all_violations = {}
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                v = scan_file(filepath)
                if v:
                    all_violations[filepath] = v
                    
    total = 0
    out_path = '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/reviewer_final_1_round4/rule22_violations.txt'
    with open(out_path, 'w', encoding='utf-8') as out:
        out.write("Rule 22 Violations Found:\n")
        for filepath, v_list in all_violations.items():
            out.write(f"\nFile: {filepath}\n")
            for line_num, block in v_list:
                total += 1
                out.write(f"Line {line_num}:\n")
                out.write("--- Block ---\n")
                out.write(block + "\n")
                out.write("-------------\n")
        out.write(f"\nTotal violations found: {total}\n")
    print(f"Done scanning. Found {total} violations. Output written to {out_path}")

if __name__ == '__main__':
    main()
