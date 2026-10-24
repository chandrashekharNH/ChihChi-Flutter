// Slims a detailed car model (.glb) into a Turbo Race car for phones.
//
//   node optimize_car.mjs <in.glb> <out.glb> [--ratio 0.25] [--error 0.002]
//
// What it does, so every racer car looks the same to the game:
// - drops what is never seen from the chase camera (interior, engine, pedals, wipers, brake pads)
// - keeps one node per wheel, named WheelFrontL / WheelFrontR / WheelRearL / WheelRearR, with its
//   origin at the hub, so the game can spin and steer it
// - joins everything else into one "Body" node, one draw per material
// - renames the main paint material "Paint" (the game recolours it per racer) and turns glass into
//   cheap tinted glass (no transmission, which is slow on phones)
// - simplifies the meshes and shrinks textures to 1024 px WebP
//
// Models from other sources (AI generators, stores) work if their wheels are separate nodes whose
// names contain "Wheel" plus FrontL/FrontR/RearL/RearR, and their body paint material name starts
// with "Paint".

import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dedup, join, prune, simplify, textureCompress, weld } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';

const [input, output, ...flags] = process.argv.slice(2);
if (!input || !output) {
  console.error('Usage: node optimize_car.mjs <in.glb> <out.glb> [--ratio 0.25]');
  process.exit(1);
}
const ratio = flags.includes('--ratio') ? Number(flags[flags.indexOf('--ratio') + 1]) : 0.25;
// How far (as a share of the model's size) simplified surfaces may move. Far cars can lose more.
const error = flags.includes('--error') ? Number(flags[flags.indexOf('--error') + 1]) : 0.002;

const hidden = /^(Interior|Engine|Axles)|Wipers|BrakePad|Pedal|Steering|HoodInterior|HoodUnder/;
const wheelNames = ['WheelFrontL', 'WheelFrontR', 'WheelRearL', 'WheelRearR'];

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const root = doc.getRoot();
const scene = root.getDefaultScene() ?? root.listScenes()[0];

// 1. Remove what the camera never sees.
let removed = 0;
for (const node of root.listNodes()) {
  if (hidden.test(node.getName())) {
    node.listChildren().forEach((c) => c.dispose());
    node.dispose();
    removed++;
  }
}

// 2. One material per look: no paint variants, glass without transmission.
root.listExtensionsUsed().find((e) => e.extensionName === 'KHR_materials_variants')?.dispose();
for (const material of root.listMaterials()) {
  const name = material.getName();
  if (/^Paint 1/.test(name) && !/Carmine/.test(name)) material.dispose();
  else if (/^Paint 1/.test(name)) material.setName('Paint');
  if (/^Paint 2/.test(name) && !/Carmine/.test(name)) material.dispose();
  if (name === 'Glass') {
    material.setExtension('KHR_materials_transmission', null);
    material.setBaseColorFactor([0.04, 0.05, 0.07, 0.82]).setAlphaMode('BLEND').setRoughnessFactor(0.05).setMetallicFactor(0.2);
  }
}

// 3. Regroup: the root keeps its own transform (it turns the Z-up model upright); under it go
//    one Body node and the four wheel nodes.
const top = scene.listChildren()[0];
const body = doc.createNode('Body');
const worldOf = (n) => n.getWorldMatrix();
const invert = (m) => {
  // Affine 4x4 inverse (column-major), enough for these rigid transforms with scale.
  const [a00, a01, a02, , a10, a11, a12, , a20, a21, a22, , a30, a31, a32] = m;
  const det = a00 * (a11 * a22 - a12 * a21) - a01 * (a10 * a22 - a12 * a20) + a02 * (a10 * a21 - a11 * a20);
  const i = 1 / det;
  const r = [
    (a11 * a22 - a12 * a21) * i, (a02 * a21 - a01 * a22) * i, (a01 * a12 - a02 * a11) * i, 0,
    (a12 * a20 - a10 * a22) * i, (a00 * a22 - a02 * a20) * i, (a02 * a10 - a00 * a12) * i, 0,
    (a10 * a21 - a11 * a20) * i, (a01 * a20 - a00 * a21) * i, (a00 * a11 - a01 * a10) * i, 0,
    0, 0, 0, 1,
  ];
  r[12] = -(a30 * r[0] + a31 * r[4] + a32 * r[8]);
  r[13] = -(a30 * r[1] + a31 * r[5] + a32 * r[9]);
  r[14] = -(a30 * r[2] + a31 * r[6] + a32 * r[10]);
  return r;
};
const mul = (a, b) => {
  const r = new Array(16).fill(0);
  for (let c = 0; c < 4; c++) for (let row = 0; row < 4; row++) for (let k = 0; k < 4; k++) r[c * 4 + row] += a[k * 4 + row] * b[c * 4 + k];
  return r;
};
/** Moves `node` under `parent` without moving it in the world. */
const reparent = (node, parent) => {
  const local = mul(invert(worldOf(parent)), worldOf(node));
  node.setMatrix(local);
  parent.addChild(node);
};
/** Lifts every descendant of `group` to be its direct child (so they can be joined). */
const flattenInto = (group, from = group) => {
  for (const child of [...from.listChildren()]) {
    flattenInto(group, child);
    if (from !== group) reparent(child, group);
  }
};

top.addChild(body);
body.setMatrix([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
if (top.getMesh()) {
  const underside = doc.createNode('Underside').setMesh(top.getMesh());
  top.setMesh(null);
  body.addChild(underside);
}
for (const child of [...top.listChildren()]) {
  if (child === body) continue;
  const wheel = wheelNames.find((w) => child.getName() === w);
  if (wheel) {
    flattenInto(child);
  } else {
    reparent(child, body);
  }
}
flattenInto(body);
top.setName('Car');

// 4. Weld, simplify, join siblings (one draw per material), drop leftovers, shrink textures.
await MeshoptSimplifier.ready;
await doc.transform(
  weld(),
  simplify({ simplifier: MeshoptSimplifier, ratio, error, lockBorder: false }),
  join({ keepNamed: false }),
  dedup(),
  prune({ keepLeaves: false }),
  textureCompress({ encoder: sharp, targetFormat: 'webp', resize: [1024, 1024] }),
);

// Wheels must survive as named nodes; check and report.
const names = new Set(root.listNodes().map((n) => n.getName()));
const missing = wheelNames.filter((w) => !names.has(w));
if (missing.length) {
  console.error(`Missing wheel nodes after optimising: ${missing.join(', ')}`);
  process.exit(2);
}
if (!root.listMaterials().some((m) => m.getName() === 'Paint')) {
  console.error('No material named "Paint" was found; the game cannot recolour this car.');
  process.exit(3);
}

let triangles = 0;
let draws = 0;
for (const mesh of root.listMeshes()) {
  for (const prim of mesh.listPrimitives()) {
    draws++;
    triangles += (prim.getIndices()?.getCount() ?? prim.getAttribute('POSITION').getCount()) / 3;
  }
}
await io.write(output, doc);
console.log(`removed ${removed} hidden parts; ${Math.round(triangles)} triangles in ${draws} draws; ` +
  `${root.listMaterials().length} materials; ${root.listTextures().length} textures`);
