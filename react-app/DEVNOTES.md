## Setup

- Initially created via Create React App

```sh
npx create-react-app react-app
```

Note: Due to some issues with node version v21.7.1 and the generated package.json I had to run

```sh
npm audit fix --force
```

and update package.json to workaround SSL issues with the legacy provider.

