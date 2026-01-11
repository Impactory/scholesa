// generate-tree.js
import fs from 'fs'
import path from 'path'

function walk(dir, depth = 0) {
  const indent = '  '.repeat(depth)
  let output = `${indent}- **${path.basename(dir)}**\n`

  const entries = fs.readdirSync(dir, { withFileTypes: true })
  for (const entry of entries) {
    const full = path.join(dir, entry.name)

    if (entry.isDirectory()) {
      output += walk(full, depth + 1)
    } else {
      output += `${indent}  - ${entry.name}\n`
    }
  }
  return output
}

const root = process.cwd()
const markdown = `# Directory Tree\n\n${walk(root)}`
fs.writeFileSync('tree.md', markdown)

console.log('tree.md created')