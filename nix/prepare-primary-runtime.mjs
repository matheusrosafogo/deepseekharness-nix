/** Assemble the locked Desktop primary runtime from Nix-provided assets. */

import { mkdirSync, readFileSync, rmSync, symlinkSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { preparePrimaryRuntime, smokePrimaryRuntime } from '../scripts/primary-runtime/prepare.ts'

const root = fileURLToPath(new URL('..', import.meta.url))
const assetsFile = process.env.PRIMARY_RUNTIME_ASSETS
if (assetsFile === undefined || assetsFile === '') {
  throw new Error('primary runtime: PRIMARY_RUNTIME_ASSETS is required')
}

const cache = process.env.PRIMARY_RUNTIME_CACHE ?? join(process.env.TMPDIR ?? '/tmp', 'dsh-primary-runtime-cache')
mkdirSync(cache, { recursive: true })

for (const asset of JSON.parse(readFileSync(assetsFile, 'utf8'))) {
  if (typeof asset.sha256 !== 'string' || typeof asset.path !== 'string') {
    throw new Error('primary runtime: invalid asset entry')
  }
  const destination = join(cache, asset.sha256)
  rmSync(destination, { force: true })
  symlinkSync(asset.path, destination)
}

const version = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version
await preparePrimaryRuntime({
  target: 'linux-x64',
  output: root,
  cache,
  version,
})

const payload = join(root, 'primary-runtime')
if (process.env.PRIMARY_RUNTIME_SMOKE !== '0') {
  smokePrimaryRuntime(payload)
}
