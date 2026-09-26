import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, extname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { createElement } from "react";
import { createMemoryHistory, RouterProvider } from "@tanstack/react-router";
// renderToString, not renderToStaticMarkup: the latter drops hydration metadata
// and inlines React 19 float tags that the client hoists to <head>, which shows
// up as a React #418 text mismatch on hydrate.
import { renderToString } from "react-dom/server";
import { createServer } from "vite";

const root = resolve(import.meta.dirname, "..");
const dist = resolve(root, "dist");
const builtAssets = await readdir(resolve(dist, "assets"));
const tempRoot = resolve(tmpdir());
const cacheDir = await mkdtemp(join(tempRoot, "notic-vite-prerender-"));

function builtAsset(source) {
  const filename = basename(source);
  const extension = extname(filename);
  const stem = basename(filename, extension);
  const matches = builtAssets.filter(
    (candidate) => candidate === filename || (candidate.startsWith(`${stem}-`) && candidate.endsWith(extension)),
  );
  if (matches.length !== 1) throw new Error(`Expected one built asset for ${source}, found ${matches.length}`);
  return `/assets/${matches[0]}`;
}

const assetUrls = new Map([
  ["assets/notic-icon.svg", "/assets/notic-icon.svg"],
  ["downloads/Notic-1.0-macOS.dmg", "/downloads/Notic-1.0-macOS.dmg"],
]);

const pages = [
  { output: "index.html", path: "/", template: "index.html" },
  { output: "release-notes/index.html", path: "/release-notes", template: "release-notes/index.html" },
  { output: "privacy/index.html", path: "/privacy", template: "privacy/index.html" },
];

const builtDocument = await readFile(resolve(dist, "index.html"), "utf8");
const appTags = [...builtDocument.matchAll(/<(?:script|link)\b[^>]*(?:src|href)="\/assets\/[^>]+>(?:<\/script>)?/g)]
  .map(([tag]) => tag)
  .join("\n    ");
if (!appTags.includes('<script type="module"')) throw new Error("Missing built SPA entry");

const server = await createServer({
  root,
  cacheDir,
  appType: "custom",
  logLevel: "error",
  server: { middlewareMode: true },
});

try {
  const { createAppRouter } = await server.ssrLoadModule("/src/router.tsx");
  for (const page of pages) {
    const router = createAppRouter(createMemoryHistory({ initialEntries: [page.path] }));
    await router.load();
    let markup = renderToString(createElement(RouterProvider, { router }));
    for (const [source, publicUrl] of assetUrls) {
      markup = markup.replaceAll(pathToFileURL(resolve(root, source)).href, publicUrl);
    }
    if (markup.includes("file://")) throw new Error(`Local file URL leaked into ${page.output}`);

    const output = resolve(dist, page.output);
    const document =
      page.output === "index.html"
        ? builtDocument
        : (await readFile(resolve(root, page.template), "utf8"))
            .replace(/\s*<script type="module" src="\/src\/main\.tsx"><\/script>/, "")
            .replace("</head>", `    ${appTags}\n  </head>`);
    if (!document.includes('<div id="root"></div>')) throw new Error(`Missing empty root in ${page.output}`);
    await mkdir(dirname(output), { recursive: true });
    await writeFile(output, document.replace('<div id="root"></div>', `<div id="root">${markup}</div>`));
  }
} finally {
  await server.close();
  if (dirname(cacheDir) !== tempRoot || !basename(cacheDir).startsWith("notic-vite-prerender-")) {
    throw new Error(`Refusing to remove unexpected cache directory: ${cacheDir}`);
  }
  await rm(cacheDir, { recursive: true, force: true });
}
