import re
import os

def summarize():
    with open("violations.txt", "r", encoding="utf-8") as f:
        content = f.read()
        
    files = re.findall(r'File: (.+):\d+', content)
    summary = {}
    for file in files:
        summary[file] = summary.get(file, 0) + 1
        
    print("Violations by file:")
    for file, count in sorted(summary.items(), key=lambda x: x[1], reverse=True):
        print(f"- {file}: {count} violations")

if __name__ == "__main__":
    summarize()
