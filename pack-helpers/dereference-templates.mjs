#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';

const ROOT = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const TEMPLATES_DIR = path.join(ROOT, 'templates');

let dereffed = 0;

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isSymbolicLink()) {
      const resolved = fs.realpathSync(full);
      const content = fs.readFileSync(resolved);
      const mode = fs.statSync(resolved).mode;
      fs.unlinkSync(full);
      fs.writeFileSync(full, content);
      fs.chmodSync(full, mode);
      dereffed += 1;
    } else if (entry.isDirectory()) {
      walk(full);
    }
  }
}

walk(TEMPLATES_DIR);
console.log(`[prepack] dereferenced ${dereffed} symlink(s) in templates/`);
