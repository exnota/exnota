# Svelte

## VS Code

* An error like `Cannot find module './App.svelte'` in a new project can be fixed by adding this to `settings.json`, assuming the official Svelte plugin is installed:

    ```json
    "svelte.enable-ts-plugin": true
    ```
