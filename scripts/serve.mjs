// Serves a folder on localhost for looking at the gallery: node serve.mjs ../gallery 4174
import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { extname, join, resolve } from "node:path";

const dir = resolve(process.argv[2] ?? "../gallery");
const port = Number(process.argv[3] ?? 4174);
const types = { ".html": "text/html; charset=utf-8", ".svg": "image/svg+xml", ".js": "text/javascript", ".css": "text/css" };
createServer((req, res) => {
  const path = join(dir, req.url === "/" ? "index.html" : decodeURIComponent(req.url.split("?")[0]));
  if (!path.startsWith(dir) || !existsSync(path)) {
    res.statusCode = 404;
    res.end("not found");
    return;
  }
  res.setHeader("content-type", types[extname(path)] ?? "application/octet-stream");
  res.end(readFileSync(path));
}).listen(port, () => console.log(`http://localhost:${port}/`));
