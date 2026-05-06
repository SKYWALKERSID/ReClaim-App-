import os
import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace .withOpacity(X) with .withValues(alpha: X)
    new_content = re.sub(r'\.withOpacity\(([\d.]+)\)', r'.withValues(alpha: \1)', content)
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed: {filepath}")

def main():
    root_dir = r"C:\Users\siddh\Desktop\Hackathon\apps\mobile\lib"
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.dart'):
                fix_file(os.path.join(root, file))

if __name__ == "__main__":
    main()
