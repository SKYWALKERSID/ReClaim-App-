
with open(r'c:\Users\siddh\Desktop\Hackathon\apps\mobile\lib\features\insights\insights_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# We want to remove lines between line 425 and 493 (1-indexed)
# Index 424 to 492
new_lines = lines[:424] + lines[493:]

with open(r'c:\Users\siddh\Desktop\Hackathon\apps\mobile\lib\features\insights\insights_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print("File updated successfully")
