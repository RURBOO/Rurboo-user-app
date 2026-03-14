import os
import re

root_dir = 'lib'
patterns = [
    r'color\s*:\s*Colors\.black87\s*,?\s*',
    r'color\s*:\s*Colors\.black\s*,?\s*',
    r'color\s*:\s*Colors\.grey(?:\[\d+\])?!?\s*,?\s*',
    r'color\s*:\s*AppColors\.textPrimary\s*,?\s*',
    r'color\s*:\s*AppColors\.textSecondary\s*,?\s*',
]
combined_pattern = re.compile('|'.join(patterns), re.MULTILINE)

def fix_file(path):
    try:
        with open(path, 'r') as f:
            content = f.read()
        
        new_content = combined_pattern.sub('', content)
        
        if new_content != content:
            with open(path, 'w') as f:
                f.write(new_content)
            return True
    except Exception as e:
        print(f"Error processing {path}: {e}")
    return False

count = 0
for root, _, files in os.walk(root_dir):
    for name in files:
        if name.endswith('.dart'):
            if fix_file(os.path.join(root, name)):
                print(f"Fixed: {os.path.join(root, name)}")
                count += 1
print(f"Total files updated: {count}")
