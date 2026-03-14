import os
import re

def fix_file(path):
    try:
        with open(path, 'r') as f:
            content = f.read()
        
        # 1. Fix orphaned .shade after BorderSide or TextStyle or just in copyWith
        # Pattern: (.shadeNNN -> (color: Colors.grey.shadeNNN
        # Pattern: , .shadeNNN -> , color: Colors.grey.shadeNNN
        c1 = re.sub(r'\(\s*\.shade', '(color: Colors.grey.shade', content)
        c2 = re.sub(r',\s*\.shade', ', color: Colors.grey.shade', c1)
        
        # 2. Fix orphaned .withValues
        # Pattern: (.withValues -> (color: Colors.black.withValues
        # Pattern: , .withValues -> , color: Colors.black.withValues
        c3 = re.sub(r'\(\s*\.withValues', '(color: Colors.black.withValues', c2)
        c4 = re.sub(r',\s*\.withValues', ', color: Colors.black.withValues', c3)
        
        # 3. Fix cases where color: was left but value was stripped
        c5 = re.sub(r'color\s*:\s*\.shade', 'color: Colors.grey.shade', c4)
        c6 = re.sub(r'color\s*:\s*\.withValues', 'color: Colors.black.withValues', c5)

        if c6 != content:
            with open(path, 'w') as f:
                f.write(c6)
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
    print(f"Precision fixed {count} files in {root_dir}")

