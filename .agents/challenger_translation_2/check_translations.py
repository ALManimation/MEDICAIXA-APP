import os
import re
import json

def check_translations():
    # Paths to language files
    lang_dir = "/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/assets/lang"
    langs = ["pt", "en", "es"]
    lang_data = {}
    
    # 1. Load the JSON files
    for lang in langs:
        path = os.path.join(lang_dir, f"{lang}.json")
        if not os.path.exists(path):
            print(f"Error: {path} does not exist!")
            return
        with open(path, 'r', encoding='utf-8') as f:
            lang_data[lang] = json.load(f)
            
    # Extract keys under "web" and "lcd"
    keys_by_lang = {}
    for lang in langs:
        keys_by_lang[lang] = {
            "web": set(lang_data[lang].get("web", {}).keys()),
            "lcd": set(lang_data[lang].get("lcd", {}).keys()),
            "all": set(lang_data[lang].get("web", {}).keys()).union(set(lang_data[lang].get("lcd", {}).keys()))
        }
        
    print(f"Loaded keys count:")
    for lang in langs:
        print(f"  {lang}: web={len(keys_by_lang[lang]['web'])}, lcd={len(keys_by_lang[lang]['lcd'])}, total={len(keys_by_lang[lang]['all'])}")
        
    # 2. Check for mismatches between language files
    mismatches_found = False
    all_keys_union = keys_by_lang["pt"]["all"].union(keys_by_lang["en"]["all"]).union(keys_by_lang["es"]["all"])
    
    print("\n--- Language Key Gaps ---")
    for lang in langs:
        missing = all_keys_union - keys_by_lang[lang]["all"]
        if missing:
            print(f"Language '{lang}' is missing the following keys:")
            for m in sorted(missing):
                # Check where it is defined
                defined_in = [l for l in langs if m in keys_by_lang[l]["all"]]
                print(f"  - {m} (defined in: {', '.join(defined_in)})")
            mismatches_found = True
        else:
            print(f"Language '{lang}' has 0 missing keys relative to others.")

    # 3. Find all t() usages in lib/
    lib_dir = "/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/lib"
    t_pattern = re.compile(r'\bt\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]')
    
    code_keys = {}
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    matches = t_pattern.findall(content)
                    for match in matches:
                        code_keys.setdefault(match, []).append(os.path.relpath(path, lib_dir))
                        
    print("\n--- Code Key Verification ---")
    print(f"Found {len(code_keys)} unique keys referenced in code.")
    
    missing_in_json = {}
    for key, files in sorted(code_keys.items()):
        # Check if key is present in pt, en, es
        for lang in langs:
            if key not in keys_by_lang[lang]["all"]:
                missing_in_json.setdefault(key, []).append((lang, files))
                
    if missing_in_json:
        print("\nKeys referenced in code that are missing in translation files:")
        for key, info in sorted(missing_in_json.items()):
            langs_missing = [x[0] for x in info]
            files_referenced = info[0][1]
            print(f"  - Key: '{key}'")
            print(f"    Missing in: {langs_missing}")
            print(f"    Referenced in: {files_referenced}")
        mismatches_found = True
    else:
        print("All keys referenced in t() in code are present in pt.json, en.json, and es.json!")

    # Check for keys in JSON but NOT used in code (potential dead translations)
    unused_keys = all_keys_union - set(code_keys.keys())
    print(f"\nFound {len(unused_keys)} keys in JSON that are not referenced via t('key') in code.")
    # (Some might be dynamically generated, or used differently, or just unused)
    # We will list them as reference.
    if unused_keys:
        print("Some unused keys (first 20):")
        for k in sorted(unused_keys)[:20]:
            print(f"  - {k}")

if __name__ == "__main__":
    check_translations()
