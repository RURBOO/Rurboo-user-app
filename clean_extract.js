const fs = require('fs');
let arr = JSON.parse(fs.readFileSync('user_extracted.json', 'utf8'));
const clean = [];
for (const s of arr) {
  if (s.includes('replaceAll')) continue;
  if (s.includes('\\n')) continue;
  if (s.includes('\n')) continue;
  if (!s.includes(' ') && s === s.toLowerCase()) continue;
  if (s.length < 3) continue;
  if (s.startsWith('assets/')) continue;
  clean.push(s);
}
fs.writeFileSync('user_extracted_clean.json', JSON.stringify(clean, null, 2));
console.log('Cleaned strings:', clean.length);
