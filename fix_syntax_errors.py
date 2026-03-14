import os
import re

root_dir = 'lib'
# Fix orphaned .withValues by prepending 'color: Colors.black' 
# or just 'Colors.black' depending on context.
# Most cases seem to be like BoxShadow(.withValues...) or color: .withValues...
# Actually, if the 'color:' label was removed, we should restore it.

def fix_file(path):
    try:
        with open(path, 'r') as f:
            content = f.read()
        
        # 1. Fix cases where '.withValues' is the first thing in parentheses (e.g. BoxShadow)
        # We restore 'color: Colors.black.withValues'
        new_content = re.sub(r'\(\s*\.withValues', '(color: Colors.black.withValues', content)
        
        # 2. Fix cases where it's preceded by a comma (e.g. other arguments in BoxShadow)
        new_content = re.sub(r',\s*\.withValues', ', color: Colors.black.withValues', new_content)

        # 3. Fix cases where 'color:' was removed but '.withValues' remains
        # Actually my pattern above covers cases inside parens.
        # Let's check if there are others like 'color: .withValues' (though unlikely with my prev script)
        new_content = re.sub(r'color\s*:\s*\.withValues', 'color: Colors.black.withValues', new_content)
        
        if new_content != content:
            with open(path, 'w') as f:
                f.write(new_content)
            return True
    except Exception as e:
        print(f"Error: {e}")
    return False

count = 0
for root, _, files in os.walk(root_dir):
    for name in files:
        if name.endswith('.dart'):
            if fix_file(os.path.join(root, name)):
                print(f"Fixed syntax in: {os.path.join(root, name)}")
                count += 1
print(f"Total files fixed: {count}")
