# Parties App (Flutter Web)

This project is a Flutter Parties application with responsive Home / Detail / Edit / Register flows.

## Build for Web

From project root:

```bash
flutter pub get
flutter build web --release --no-wasm-dry-run -O1
```

Build output is generated in:

- `build/web`

## Deploy (Fastest): Netlify Drag & Drop

1. Open https://app.netlify.com/drop
2. Drag folder `build/web` into the page
3. Netlify will provide a public URL immediately

## Deploy with Netlify CLI

```bash
npm i -g netlify-cli
netlify login
netlify deploy --prod --dir=build/web
```

## Deploy to GitHub Pages (when repo exists)

If you later initialize Git and push to GitHub, use:

```bash
git init
git add .
git commit -m "init"
git branch -M main
git remote add origin <your-repo-url>
git push -u origin main
```

Then build using base path (replace `<repo-name>`):

```bash
flutter build web --release --base-href /<repo-name>/ --no-wasm-dry-run -O1
```

Publish contents of `build/web` to the `gh-pages` branch.

## Notes

- If normal release build fails with `dart2js` process exit, keep `-O1`.
- `file_picker` plugin warnings for desktop platforms do not block web deployment.
