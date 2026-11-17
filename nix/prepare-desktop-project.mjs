/** Create the disposable Desktop project used by an unpackaged Electron shell. */

import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { prepareDevelopmentProject } from '../apps/desktop/scripts/development-project.ts'
import { DESKTOP_HOST_PROTOCOL_VERSION } from '../apps/desktop/src/host-protocol.ts'

const root = fileURLToPath(new URL('..', import.meta.url))
const desktopVersion = JSON.parse(readFileSync(join(root, 'apps/desktop/package.json'), 'utf8')).version
const pnpmVersion = JSON.parse(readFileSync(join(root, 'apps/desktop/node_modules/pnpm/package.json'), 'utf8')).version

prepareDevelopmentProject({
  projectDir: join(root, 'apps/desktop/.desktop-build/development/project'),
  cliDir: join(root, 'apps/cli'),
  hostDir: join(root, 'apps/desktop-host'),
  dependencyDir: join(root, 'node_modules/.pnpm/node_modules'),
  release: {
    schemaVersion: 1,
    version: desktopVersion,
    hostProtocolVersion: DESKTOP_HOST_PROTOCOL_VERSION,
    nodeVersion: process.versions.node,
    pnpmVersion,
  },
  target: 'linux-x64',
})
