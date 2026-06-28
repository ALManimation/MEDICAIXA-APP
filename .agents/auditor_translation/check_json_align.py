import json
import os
import sys

def get_keys(data, parent_key=''):
    keys = set()
    if isinstance(data, dict):
        for k, v in data.items():
            full_key = f"{parent_key}.{k}" if parent_key else k
            keys.add(full_key)
            keys.update(get_keys(v, full_key))
    return keys

def compare_json(file1, file2):
    try:
        with open(file1, 'r', encoding='utf-8') as f:
            data1 = json.load(f)
    except Exception as e:
        print(f"Error reading/parsing {file1}: {e}")
        return None
        
    try:
        with open(file2, 'r', encoding='utf-8') as f:
            data2 = json.load(f)
    except Exception as e:
        print(f"Error reading/parsing {file2}: {e}")
        return None
        
    keys1 = get_keys(data1)
    keys2 = get_keys(data2)
    
    missing_in_2 = keys1 - keys2
    missing_in_1 = keys2 - keys1
    
    return missing_in_1, missing_in_2

def main():
    base_dir = "/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app"
    pt_path = os.path.join(base_dir, "assets/lang/pt.json")
    en_path = os.path.join(base_dir, "assets/lang/en.json")
    es_path = os.path.join(base_dir, "assets/lang/es.json")
    
    files = [pt_path, en_path, es_path]
    
    # 1. Syntactic validity
    print("--- Syntactic Validity Check ---")
    all_valid = True
    for fp in files:
        if not os.path.exists(fp):
            print(f"File not found: {fp}")
            all_valid = False
            continue
        try:
            with open(fp, 'r', encoding='utf-8') as f:
                json.load(f)
            print(f"PASS: {os.path.basename(fp)} is valid JSON.")
        except Exception as e:
            print(f"FAIL: {os.path.basename(fp)} has invalid JSON: {e}")
            all_valid = False
            
    if not all_valid:
        sys.exit(1)
        
    # 2. Key alignment
    print("\n--- Key Alignment Check ---")
    align_ok = True
    
    # Compare PT and EN
    diff_pt_en = compare_json(pt_path, en_path)
    if diff_pt_en is None:
        align_ok = False
    else:
        missing_in_pt, missing_in_en = diff_pt_en
        if missing_in_en:
            print(f"Missing in en.json (present in pt.json): {len(missing_in_en)} keys")
            for k in sorted(missing_in_en)[:10]:
                print(f"  - {k}")
            if len(missing_in_en) > 10:
                print("  ... and more")
            align_ok = False
        if missing_in_pt:
            print(f"Missing in pt.json (present in en.json): {len(missing_in_pt)} keys")
            for k in sorted(missing_in_pt)[:10]:
                print(f"  - {k}")
            if len(missing_in_pt) > 10:
                print("  ... and more")
            align_ok = False

    # Compare PT and ES
    diff_pt_es = compare_json(pt_path, es_path)
    if diff_pt_es is None:
        align_ok = False
    else:
        missing_in_pt, missing_in_es = diff_pt_es
        if missing_in_es:
            print(f"Missing in es.json (present in pt.json): {len(missing_in_es)} keys")
            for k in sorted(missing_in_es)[:10]:
                print(f"  - {k}")
            if len(missing_in_es) > 10:
                print("  ... and more")
            align_ok = False
        if missing_in_pt:
            print(f"Missing in pt.json (present in es.json): {len(missing_in_pt)} keys")
            for k in sorted(missing_in_pt)[:10]:
                print(f"  - {k}")
            if len(missing_in_pt) > 10:
                print("  ... and more")
            align_ok = False

    if align_ok:
        print("PASS: pt.json, en.json, and es.json are completely aligned!")
        sys.exit(0)
    else:
        print("FAIL: Key alignment check failed.")
        sys.exit(1)

if __name__ == '__main__':
    main()
