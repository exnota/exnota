# Architecture

## State context layers

### Principles

To reduce state complexity, the providers that manage state are grouped into layers with the following principles:

* **Grouping**: Each layer is a collection of state that has a similar impact on the needs of the app.
  * E.g. The theme and language are both settings specific to the app, not the user, so they go in the App layer which is above the User Auth layer.
* **Accessing**: Inner layers can synchronously access state from outer layers.
  * E.g. FlutterSecureStorage access is async, the Environment layer loader will load this before inner layers are rendered, thus providing async access.
  * This is not a hard limitation, but should be abided by.
* **Mutating**: Changing the state of outer layer will likely cause a re-render and re-generation of inner layer state.
  * E.g. Changing the environment causes user auth and routing to be re-generated.

This reduces complexity by:

* Isolating dependency complexity to each layer
  * When adding/modifying providers, you only need to consider dependencies within the same layer. You can assume everything in layers above is accessible.
  * E.g. 3 providers depending on each other are simpler than 15.
* Making state re-generation logic clearer.
* Simplifying access to async providers.

### Components

Each layer can have:

* One context loader
  * This is a widget that eagerly initializes any async providers.
* Zero or more internal, async providers
  * These are used by the context loader for initialization.
* One or more non-async providers
  * These can chain an async provider, using `.requireValue` or simply contain non-async data

### Layers

1. **Device** (outermost)
   * State fixed when the app is launched. Never expected to change.
   * Most logic performed in `main.dart`
2. **Environment**
   * Development environment.
3. **User**
   * The logged in user.
   * Needs URLs from the Environment layer.
4. **App**
   * Specifics for rendering the Material App.
   * E.g. theme, router.
   * Theme must be in the same layer or an inner layer from router, to avoid a change in theme regenerating the router and user losing their place.

Future ideas:

* Workspace(s) context
  * I.e. only sync blocks for the current workspaces the user cares about
* Subapp contexts
  * I.e. only watch for live updates for the subapp the user is in (probably only one subapp for now: blocks)

### Best practices

#### Creating/adding

#### Consuming
