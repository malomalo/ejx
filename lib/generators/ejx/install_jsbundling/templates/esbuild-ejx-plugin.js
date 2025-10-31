// Compiles EJX/EJS templates to ES modules by calling the Ruby gem.
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'

export default function ejxPlugin({ ruby = 'ruby' } = {}) {
  const filter = /\.(ejx|ejs|html\.ejx|html\.ejs|ejx\.html|ejs\.html)$/

  return {
    name: 'ejx',
    setup(build) {
      // Resolve bare import 'ejx' to vendored runtime under app/javascript/vendor/ejx.js
      build.onResolve({ filter: /^ejx$/ }, (args) => {
        return { path: `${process.cwd()}/app/javascript/vendor/ejx.js` }
      })

      build.onLoad({ filter }, (args) => {
        const source = fs.readFileSync(args.path, 'utf8')
        const proc = spawnSync(
          ruby,
          ['-rbundler/setup', '-rejx', '-e', 'print EJX.compile(STDIN.read)'],
          { input: source, encoding: 'utf8' }
        )

        if (proc.status !== 0) {
          return { errors: [{ text: (proc.stderr || proc.stdout || 'EJX compile failed').toString() }] }
        }

        return { contents: proc.stdout, loader: 'js' }
      })
    }
  }
}
