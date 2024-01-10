# Imports

## CommonJS vs ESM

NestJS currently only supports CommonJS modules: https://github.com/nestjs/nest/pull/8736

So to import a package that is ESM-only, we need a workaround. The options are:

1. Dynamic import: `const fetch = await 'node-fetch'`

2. Create a wrapper, as per https://github.com/nestjs/nest/pull/8736#issuecomment-1378356632

3. Wrap the ESM package in a NestJS service: https://github.com/nestjs/nest/pull/8736#issuecomment-1236321406
   - This might also be helpful https://docs.nestjs.com/fundamentals/dynamic-modules
   - And this https://dev.to/wolfejw86/the-commonjs-vs-es-modules-war-is-taxing-for-us-regular-folks-out-here-one-way-to-interop-55e

4. Eval hackery. See [Variant 3: Import and save to local variable](https://stackoverflow.com/a/75287028).

Some more references
- https://stackoverflow.com/a/75287028
- https://dev.to/wolfejw86/the-commonjs-vs-es-modules-war-is-taxing-for-us-regular-folks-out-here-one-way-to-interop-55e
- https://gist.github.com/sindresorhus/a39789f98801d908bbc7ff3ecc99d99c

## Some other import-related things

* `import * as fs from 'fs';`
* `"esModuleInterop": true` in tsconfig.json