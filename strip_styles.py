import os
import re

dir_path = '/Users/adarshkumarpandey21/Desktop/R/Rurboo-user-app/lib'
colors_to_remove = r'Colors\.black87|Colors\.black|Colors\.grey(?:\[\d+\])?!?|AppColors\.textPrimary|AppColors\.textSecondary'
pattern = re.compile(r'(TextStyle\s*\([^)]*?)color\s*:\s*(?:' + colors_to_remove + r')\s*,?\s*([^)]*\))')

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    new_content = content
    # Loop to catch multiple occurrences or do it properly
    # Using re.sub with a loop because the first regex doesn't match nested parens well.
    # Actually, a simple text-based replace of specific common strings is safer.
    replacements = [
        (r'color: Colors.black,', ''),
        (r'color: Colors.black87,', ''),
        (r'color: AppColors.textPrimary,', ''),
        (r'color: AppColors.textSecondary,', ''),
        (r'color: Colors.grey,', ''),
    ]
    
    # We will use regex to find color: ... inside TextStyle matching non-greedy up to ')'
    # This is safe if there are no nested parentheses inside the TextStyle.
    # For nested parens (like color: ... inside a TextStyle with fontFamily), we can just replace the specific color declarations globally, BUT only on lines containing 'TextStyle' or 'Text('.
    lines = new_content.split('\n')
    changed = False
    for i, line in enumerate(lines):
        if 'TextStyle' in line or 'Text(' in line:
            orig = line
            line = re.sub(r'color\s*:\s*(Colors\.black87|Colors\.black|Colors\.grey(?:\[\d+\])?!?|AppColors\.textPrimary|AppColors\.textSecondary)\s*,?\s*', '', line)
            if orig != line:
                # If removing the color leaves an empty const TextStyle(), it becomes const TextStyle() which is fine.
                lines[i] = line
                changed = True

    if changed:
        with open(filepath, 'w') as f:
            f.write('\n'.join(lines))
        print(f"Updated {os.path.basename(filepath)}")

for root, _, files in os.walk(dir_path):
    for f in files:
        if f.endswith('.dart'):
            process_file(os.path.join(root, f))
