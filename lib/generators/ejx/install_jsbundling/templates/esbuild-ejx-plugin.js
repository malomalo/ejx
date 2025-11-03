// Compiles EJX/EJS templates to ES modules by calling the Ruby gem.
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'

export default function ejxPlugin(options = {}) {
  const { ruby = 'ruby', ...ejxOptions } = options
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
          [
            '-rbundler/setup',
            '-rjson',
            '-rejx',
            '-e',
            'opts = ENV["EJX_OPTIONS"] && JSON.parse(ENV["EJX_OPTIONS"], symbolize_names: true); print EJX.compile(STDIN.read, opts || {})'
          ],
          { input: source, encoding: 'utf8', env: { ...process.env, EJX_OPTIONS: JSON.stringify(ejxOptions || {}) } }
        )

        if (proc.status !== 0) {
          return { errors: [{ text: (proc.stderr || proc.stdout || 'EJX compile failed').toString() }] }
        }

        return { contents: proc.stdout, loader: 'js' }
      })
    }
  }
}
