const fs = require('fs');
const path = require('path');

function walk(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const stat = fs.statSync(path.join(dir, file));
    if (stat.isDirectory()) {
      walk(path.join(dir, file), fileList);
    } else if (file.endsWith('.dart') && !file.includes('.g.dart')) {
      fileList.push(path.join(dir, file));
    }
  }
  return fileList;
}

const dartFiles = walk('lib');
const strings = new Set();
const fileContentCache = {};

for (const file of dartFiles) {
  const content = fs.readFileSync(file, 'utf8');
  fileContentCache[file] = content;
  
  // Find Text('some text') avoiding $, empty string, single char, etc.
  const regex = /(?:const\s+)?Text\(\s*(['"])([^$]{2,100}?)\1\s*[,)]/g;
  let match;
  while ((match = regex.exec(content)) !== null) {
    const text = match[2].trim();
    if (/[a-zA-Z]/.test(text) && !text.includes('Provider') && !text.includes('AppLocalizations') && !text.includes('lang.getText')) {
      strings.add(text);
    }
  }

  // Also catch Text("some text",
  const regex2 = /(?:const\s+)?Text\(\s*(['"])([^$]{2,100}?)\1\s*,/g;
  while ((match = regex2.exec(content)) !== null) {
    const text = match[2].trim();
    if (/[a-zA-Z]/.test(text) && !text.includes('Provider') && !text.includes('AppLocalizations') && !text.includes('lang.getText')) {
      strings.add(text);
    }
  }
}

const arr = Array.from(strings);
fs.writeFileSync('user_extracted.json', JSON.stringify(arr, null, 2));
console.log(`Extracted ${arr.length} unique UI strings from User App.`);
