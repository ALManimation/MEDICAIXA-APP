import re

def analyze_reports_violations():
    violations_file = '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/reviewer_final_1_round4/rule22_violations.txt'
    with open(violations_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # The file contains sections starting with 'File: ' and then blocks
    # Let's parse them
    sections = content.split('\nFile: ')
    
    reports_violations = []
    
    for section in sections:
        lines = section.splitlines()
        if not lines:
            continue
        filepath = lines[0].strip()
        
        # Check if the file is in lib/features/reports
        if 'lib/features/reports' in filepath:
            # Parse line number and block content
            blocks = re.findall(r'Line (\d+):\n--- Block ---\n(.*?)\n-------------', section, re.DOTALL)
            for line_num, block in blocks:
                reports_violations.append((filepath, line_num, block.strip()))
                
    print(f"Rule 22 Violations in Reports Feature (Total: {len(reports_violations)}):")
    for fp, line_num, block in reports_violations:
        print(f"\nFile: {fp} (Line {line_num})")
        print(block)
        print("-" * 50)

if __name__ == '__main__':
    analyze_reports_violations()
