import os
import re

def fix_file(path):
    try:
        with open(path, 'r') as f:
            content = f.read()
        
        # Fix orphaned .withValues
        # Case 1: BoxShadow(.withValues...) -> BoxShadow(color: Colors.black.withValues...)
        # Case 2: , .withValues(...) -> , color: Colors.black.withValues(...)
        # Case 3: color: .withValues(...) -> color: Colors.black.withValues(...)
        
        c1 = re.sub(r'BoxShadow\(\s*\.withValues', 'BoxShadow(color: Colors.black.withValues', content)
        c2 = re.sub(r',\s*\.withValues', ', color: Colors.black.withValues', c1)
        c3 = re.sub(r'color\s*:\s*\.withValues', 'color: Colors.black.withValues', c2)
        
        # Fix TextStyle(.shade...) or style: TextStyle( .shade...)
        c4 = re.sub(r'TextStyle\(\s*\.shade', 'TextStyle(color: Colors.grey.shade', c3)
        c5 = re.sub(r'style\s*:\s*TextStyle\(\s*(\s*)', r'style: TextStyle(\1', c4) # Clean up spaces

        if c5 != content:
            with open(path, 'w') as f:
                f.write(c5)
            return True
    except Exception as e:
        print(f"Error {path}: {e}")
    return False

for root_dir in ['../Rurboo-user-app/lib', '../Rurboo-driver-app/lib']:
    count = 0
    for root, _, files in os.walk(root_dir):
        for name in files:
            if name.endswith('.dart'):
                if fix_file(os.path.join(root, name)):
                    count += 1
    print(f"Fixed {count} files in {root_dir}")

