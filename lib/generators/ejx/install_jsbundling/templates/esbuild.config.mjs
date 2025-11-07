// Minimal esbuild config that wires EJX plugin
import esbuild from 'esbuild'
import ejxPlugin from './esbuild-ejx-plugin.js'

const options = {
  entryPoints: ['app/javascript/application.js'],
  bundle: true,
  sourcemap: true,
  outdir: 'app/assets/builds',
  plugins: [ejxPlugin()]
}

if (process.argv.includes('--watch')) {
  const ctx = await esbuild.context(options)
  await ctx.watch()
  console.log('esbuild watching with EJX plugin…')
} else {
  await esbuild.build(options)
}

