# Internal tool

For bulk actions, cleanup, etc.


## Local development

```bash
npm install

npm typegen # repeat after collection schema changes

npm dev
```

Make sure the `backend` app is running.

Then go to http://localhost:5173/internal/

## Production

### Status
Not currently supported! Needs more security added first, e.g.:
- Admin-only.
- Hide everything before login.

### Tips for setting up in the fuutre
My first attempt was to serve the `build` directory in `main.go`. This worked but
required a build on every change to this app. Instead, to take advantage of
Sveltekit's hot-reload, I changed to the Vite using the Vite dev server at
http://localhost:5173/internal/.

To set this up in the future, we'll probably need to:
1. Improve security and precautions!
2. Uncomment the code in `main.go` that serves `pub_internal/build`
3. Add the `npm run build` step to `Dockerfile`

