// Regenerates every fixture from the pinned official packages. Run from
// scripts/: `npm ci && node gen_fixtures.mjs [suite...]`.
import { hex, rng, strArray, writeGen } from "./mbt.mjs";

const suites = {
  async jsonDoubles() {
    const r = rng(1);
    const view = new DataView(new ArrayBuffer(8));
    const lines = [];
    for (let i = 0; i < 10000; i++) {
      let x;
      if (i % 3 === 0) {
        view.setUint32(0, r() * 2 ** 32);
        view.setUint32(4, r() * 2 ** 32);
        x = view.getFloat64(0);
        if (!Number.isFinite(x)) x = r();
      } else if (i % 3 === 1) x = (r() - 0.5) * 10 ** Math.floor(r() * 12);
      else x = Math.round(r() * 1e6) / 100;
      lines.push(`${JSON.stringify(x)}|${hex(x)}`);
    }
    writeGen("src/internal/conform/json_doubles_gen_test.mbt", strArray("json_doubles", lines, { pub: false }));
  },
};

const wanted = process.argv.slice(2);
for (const name of wanted.length ? wanted : Object.keys(suites)) {
  await suites[name]();
}
process.exit(0);
