// Regenerates every fixture from the pinned official packages. Run from
// scripts/: `npm ci && node gen_fixtures.mjs [suite...]`.
import { hex, rng, strArray, writeGen } from "./mbt.mjs";

const canonNaN = (x) => (Number.isNaN(x) ? NaN : x);
const specials = [0, -0, 1, -1, 2, 0.5, 3, NaN, Infinity, -Infinity, 1e-300, -1e-300, 1e300, -1e300, 5e-324, 1.7976931348623157e308];

/** Inputs for a two-argument math function: specials, then random values. */
function binaryCases(f, count, pick) {
  const out = [];
  for (const a of specials) for (const b of specials) out.push([a, b]);
  const r = rng(f.name.length * 7919);
  for (let i = 0; i < count; i++) out.push(pick(r));
  return out.map(([a, b]) => `${hex(a)} ${hex(b)} ${hex(canonNaN(f(a, b)))}`);
}
const scaled = (r) => (r() - 0.5) * 10 ** Math.floor(r() * 10 - 3);

function exactCube(x) {
  if (x === 0) return x * x * x;
  const view = new DataView(new ArrayBuffer(8));
  view.setFloat64(0, Math.abs(x));
  const bits = view.getBigUint64(0);
  const exp = Number(bits >> 52n);
  const m = (bits & ((1n << 52n) - 1n)) | (1n << 52n);
  const cubed = m ** 3n;
  const drop = cubed.toString(2).length - 53;
  const q = cubed >> BigInt(drop);
  const rem = cubed - (q << BigInt(drop));
  const half = 1n << BigInt(drop - 1);
  const up = rem > half || (rem === half && (q & 1n) === 1n);
  const value = Number(q + (up ? 1n : 0n)) * 2 ** ((exp - 1075) * 3 + drop);
  return x < 0 ? -value : value;
}

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

  async jsnum() {
    const hypot = binaryCases(function hypot(a, b) { return Math.hypot(a, b); }, 5000, (r) => [scaled(r), scaled(r)]);
    const atan2 = binaryCases(function atan2(a, b) { return Math.atan2(a, b); }, 5000, (r) => [scaled(r), scaled(r)]);
    // Math.pow(x, 3) depends on the platform's C library, so the expected value
    // is the exact cube rounded to nearest, computed with BigInt.
    const r = rng(33);
    const cube = [];
    for (let i = 0; i < 8000; i++) {
      const x = i % 4 === 3 ? scaled(r) : r();
      cube.push(`${hex(x)} ${hex(3)} ${hex(exactCube(x))}`);
    }
    writeGen(
      "src/internal/fixtures/jsnum_gen.mbt",
      strArray("hypot_cases", hypot) + "\n" + strArray("atan2_cases", atan2) + "\n" + strArray("cube_cases", cube),
    );
  },
};

const wanted = process.argv.slice(2);
for (const name of wanted.length ? wanted : Object.keys(suites)) {
  await suites[name]();
}
process.exit(0);
