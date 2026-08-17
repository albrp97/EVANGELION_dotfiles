import { app } from "electron/main";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

const appPath = path.dirname(fileURLToPath(import.meta.url));
const patchedMain = path.join(appPath, "out", "main.js");
const name = "code-oss";

const fd = fs.openSync("/proc/self/comm", fs.constants.O_WRONLY);
fs.writeSync(fd, name);
fs.closeSync(fd);

process.argv.splice(
  0,
  process.argv.findIndex((arg) => arg.endsWith("/code.mjs")),
);

const packageJson = JSON.parse(
  fs.readFileSync(path.join(appPath, "package.json")),
);

app.setAppPath(appPath);
app.setDesktopName(`${name}.desktop`);
app.setName(name);
app.setPath("userCache", path.join(app.getPath("cache"), name));
app.setPath("userData", path.join(app.getPath("appData"), name));
app.setVersion(packageJson.version);

await import(patchedMain);
