def main():
    violations_file = '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/reviewer_final_1_round4/rule22_violations.txt'
    with open(violations_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split by file sections
    sections = content.split('\nFile: ')
    
    total_violations = 0
    print("Rule 22 Violations by File (Actual Counts):")
    for section in sections:
        lines = section.splitlines()
        if not lines:
            continue
        filepath = lines[0].strip()
        if filepath == "Rule 22 Violations Found:":
            continue
            
        # Count occurrences of 'Line ' in this section
        count = section.count('\nLine ')
        if count == 0:
            # Maybe it starts without a newline if it's the very first line
            count = section.count('Line ')
            
        print(f"{filepath}: {count} violations")
        total_violations += count
        
    print(f"\nTotal Rule 22 violations found: {total_violations}")

if __name__ == '__main__':
    main()
