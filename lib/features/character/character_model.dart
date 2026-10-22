import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart' as vm;

import '../../core/ui/palette.dart';
import 'avatar_appearance.dart';
import 'measured_face.dart';

// A child's character built from simple 3D shapes (big head, small body), about 1.6 units tall
// with its feet at y = 0 and facing +z — the same layout as the iOS SceneKit character. The
// painter projects these shapes and shades them so they read as round, solid parts.

enum Joint { hips, torso, head, leftArm, rightArm, leftLeg, rightLeg }

/// How a shape is lit: matte (soft), glossy (a highlight) or glow (flat, no shading).
enum Finish { matte, glossy, glow }

sealed class Shape3D {
  Shape3D(this.color, this.finish, {this.opacity = 1});
  final Color color;
  final Finish finish;
  final double opacity;
}

/// A sphere of `radius`, squashed by `scale`, centred at `center` (local to its node).
class SphereShape extends Shape3D {
  SphereShape(this.center, this.radius, super.color, super.finish, {vm.Vector3? scale, super.opacity})
      : scale = scale ?? vm.Vector3(1, 1, 1);
  final vm.Vector3 center;
  final double radius;
  final vm.Vector3 scale;
}

/// A rounded stick from `a` to `b`.
class CapsuleShape extends Shape3D {
  CapsuleShape(this.a, this.b, this.radius, super.color, super.finish);
  final vm.Vector3 a, b;
  final double radius;
}

/// A cylinder or cone between two end circles (radii `ra` at `a`, `rb` at `b`).
class FrustumShape extends Shape3D {
  FrustumShape(this.a, this.b, this.ra, this.rb, super.color, super.finish);
  final vm.Vector3 a, b;
  final double ra, rb;
}

/// A line (open or closed) through 3D points: smiles, rings, frames. `width` is in model units.
class LineShape extends Shape3D {
  LineShape(this.points, this.width, super.color, super.finish, {this.closed = false, this.filled = false});
  final List<vm.Vector3> points;
  final double width;
  final bool closed;
  final bool filled;
}

/// A box (backpack, pocket) with its centre and size.
class CuboidShape extends Shape3D {
  CuboidShape(this.center, this.size, super.color, super.finish);
  final vm.Vector3 center, size;
}

/// One part of the body: a place, a turn, a size, its shapes and the parts it carries.
class Node3D {
  Node3D({vm.Vector3? position, this.joint, this.isEye = false})
      : position = position ?? vm.Vector3.zero(),
        rest = (position ?? vm.Vector3.zero()).clone();

  vm.Vector3 position;
  final vm.Vector3 rest;
  vm.Vector3 euler = vm.Vector3.zero();
  vm.Vector3 restEuler = vm.Vector3.zero();
  vm.Vector3 scale = vm.Vector3(1, 1, 1);
  final Joint? joint;

  /// Eye sockets blink (their y scale is squeezed).
  final bool isEye;
  final List<Shape3D> shapes = [];
  final List<Node3D> children = [];

  Node3D add(Node3D child) {
    children.add(child);
    return child;
  }

  /// SceneKit order: roll (z) first, then yaw (y), then pitch (x).
  vm.Matrix4 get local =>
      vm.Matrix4.translation(position) *
      vm.Matrix4.rotationX(euler.x) *
      vm.Matrix4.rotationY(euler.y) *
      vm.Matrix4.rotationZ(euler.z) *
      vm.Matrix4.diagonal3(scale);
}

/// A built character with its named joints.
class CharacterRig {
  CharacterRig(this.root, this.joints, this.eyes);
  final Node3D root;
  final Map<Joint, Node3D> joints;
  final List<Node3D> eyes;

  Node3D operator [](Joint j) => joints[j]!;

  /// Puts every joint back to its resting pose.
  void reset() {
    for (final node in joints.values) {
      node.position = node.rest.clone();
      node.euler = node.restEuler.clone();
    }
    for (final eye in eyes) {
      eye.scale = vm.Vector3(1, 1, 1);
    }
  }
}

/// Where the drawn features sit and how big they are. The defaults are the standard cartoon face; a
/// `MeasuredFace` moves and resizes each feature to match the child's own.
class _FaceLayout {
  _FaceLayout(MeasuredFace? measured) {
    if (measured == null) return;
    double amount(String f) => measured.amount(f);
    eyeX = 0.13 * amount('eyeSpacing');
    // Eyes are already big on this face: let them differ, but only a little.
    eyeSize = amount('eyeWidth').clamp(0.82, 1.18);
    eyeOpen = amount('eyeOpen').clamp(0.82, 1.18);
    eyeTilt = (measured.proportions.eyeTilt * 1.5).clamp(-0.3, 0.3);
    browGap = amount('browGap');
    browLength = amount('browLength');
    // Starts from the standard friendly slope, so a level brow never looks cross.
    browTilt = (-0.08 + measured.proportions.browTilt).clamp(-0.3, 0.1);
    noseWidth = amount('noseWidth');
    noseLength = amount('noseLength');
    mouthWidth = amount('mouthWidth');
    mouthDrop = amount('mouthDrop');
    lipHeight = amount('lipHeight');
    // A long face gets a slightly longer chin, never a long neck.
    jaw = (amount('jawWidth').clamp(0.78, 1.12), 1 + (amount('faceLength') - 1) * 0.4);
    headWidth = measured.headWidth;
    lips = measured.lips?.color;
  }

  static const eyeY = 0.04;
  double eyeX = 0.13, eyeSize = 1, eyeOpen = 1, eyeTilt = 0, browGap = 1, browLength = 1;
  double? browTilt;
  double noseWidth = 1, noseLength = 1, mouthWidth = 1, mouthDrop = 1, lipHeight = 1;
  (double, double)? jaw;
  double? headWidth;
  Color? lips;

  /// How far forward a feature sits at (x, y): on the surface of the head, plus `lift`.
  double depth(double x, double y, double lift) => math.sqrt(math.max(0, 0.36 * 0.36 - x * x - y * y)) + lift;
}

class CharacterModel {
  static const headRadius = 0.36;

  static CharacterRig build(AvatarAppearance look) {
    final joints = <Joint, Node3D>{};
    final eyes = <Node3D>[];
    Node3D joint(Joint j, double x, double y, double z) => joints[j] = Node3D(position: vm.Vector3(x, y, z), joint: j);

    final root = Node3D();
    final skin = _skinColour(look);
    final hips = root.add(joint(Joint.hips, 0, 0.62, 0));
    _legs(hips, look, skin, joint);
    final torso = hips.add(joint(Joint.torso, 0, 0, 0));
    _body(torso, look, skin, joint);
    final head = torso.add(joint(Joint.head, 0, 0.5, 0));
    _head(head, look, skin, eyes);
    return CharacterRig(root, joints, eyes);
  }

  static vm.Vector3 _v(double x, double y, double z) => vm.Vector3(x, y, z);

  static void _legs(Node3D hips, AvatarAppearance look, Color skin, Node3D Function(Joint, double, double, double) joint) {
    final bottoms = look.bottomsColor.color;
    final dress = look.top == Top.dress;
    for (final (j, side) in [(Joint.leftLeg, -1.0), (Joint.rightLeg, 1.0)]) {
      final leg = hips.add(joint(j, side * 0.12, 0, 0));
      // Pants cover the whole leg; shorts the top half; a skirt or dress shows the legs.
      final legColour = look.bottoms == Bottoms.pants && !dress ? bottoms : skin;
      leg.shapes.add(CapsuleShape(_v(0, -0.105, 0), _v(0, -0.435, 0), 0.085, legColour, Finish.matte));
      if (look.bottoms == Bottoms.shorts && !dress) {
        leg.shapes.add(FrustumShape(_v(0, 0, 0), _v(0, -0.2, 0), 0.105, 0.105, bottoms, Finish.matte));
      }
      leg.shapes.add(SphereShape(_v(0, -0.56, 0.04), 0.1, look.shoesColor.color, Finish.glossy, scale: _v(1, 0.6, 1.5)));
    }
    if (look.bottoms == Bottoms.skirt && !dress) {
      hips.shapes.add(FrustumShape(_v(0, 0.06, 0), _v(0, -0.18, 0), 0.2, 0.3, bottoms, Finish.matte));
    }
  }

  static void _body(Node3D torso, AvatarAppearance look, Color skin, Node3D Function(Joint, double, double, double) joint) {
    final cloth = look.topColor.color;
    torso.shapes.add(CapsuleShape(_v(0, 0.13, 0), _v(0, 0.31, 0), 0.22, cloth, Finish.matte));
    switch (look.top) {
      case Top.dress:
        torso.shapes.add(FrustumShape(_v(0, 0.09, 0), _v(0, -0.25, 0), 0.2, 0.36, cloth, Finish.matte));
      case Top.hoodie:
        torso.shapes.add(LineShape(_ring(_v(0, 0.47, -0.1), 0.17, tiltX: -0.5), 0.12, cloth, Finish.matte, closed: true));
        torso.shapes.add(CuboidShape(_v(0, 0.1, 0.19), _v(0.26, 0.1, 0.02), _adjusted(cloth, -0.12), Finish.matte));
      case Top.jersey:
        // A white band hugging the body; a sleeveless cut (the arms stay bare).
        torso.shapes.add(LineShape(_ring(_v(0, 0.28, 0), 0.214, squashZ: 0.85), 0.07, const Color(0xFFFFFFFF), Finish.matte,
            closed: true));
      case Top.tee:
        break;
    }
    if (look.backpack) {
      torso.shapes.add(CuboidShape(_v(0, 0.24, -0.25), _v(0.34, 0.36, 0.16), _rotatedHue(_adjusted(cloth, 0.25)), Finish.glossy));
    }
    // Arms hang from the shoulders; a jersey is sleeveless, a hoodie has long sleeves.
    for (final (j, side) in [(Joint.leftArm, -1.0), (Joint.rightArm, 1.0)]) {
      final arm = torso.add(joint(j, side * 0.27, 0.42, 0));
      arm.restEuler = _v(0, 0, side * 0.12);
      arm.euler = arm.restEuler.clone();
      arm.shapes.add(CapsuleShape(_v(0, -0.045, 0), _v(0, -0.315, 0), 0.065, look.top == Top.hoodie ? cloth : skin, Finish.matte));
      if (look.top == Top.tee || look.top == Top.dress) {
        arm.shapes.add(FrustumShape(_v(0, 0.03, 0), _v(0, -0.11, 0), 0.085, 0.085, cloth, Finish.matte));
      }
      arm.shapes.add(SphereShape(_v(0, -0.4, 0), 0.08, skin, Finish.matte));
    }
  }

  static void _head(Node3D head, AvatarAppearance look, Color skin, List<Node3D> eyes) {
    final layout = _FaceLayout(look.measured);
    final face = head.add(Node3D(position: _v(0, 0.34, 0)));
    if (layout.headWidth != null) {
      face.scale = _v(layout.headWidth!, 1, 1);
    } else {
      switch (look.faceShape) {
        case FaceShape.round:
          break;
        case FaceShape.oval:
          face.scale = _v(0.93, 1.06, 0.97);
        case FaceShape.wide:
          face.scale = _v(1.08, 0.95, 1);
      }
    }
    final jaw = layout.jaw;
    // The jaw stretches the lower half of the head: drawn as the head plus a chin below it.
    face.shapes.add(SphereShape(_v(0, 0, 0), headRadius, skin, Finish.matte));
    if (jaw != null && (jaw.$1 != 1 || jaw.$2 != 1)) {
      face.shapes.add(SphereShape(_v(0, -0.08 * jaw.$2, 0.02), headRadius * 0.85, skin, Finish.matte,
          scale: _v(jaw.$1, jaw.$2, 0.95)));
    }
    for (final side in [-1.0, 1.0]) {
      face.shapes.add(SphereShape(_v(side * 0.35, -0.02, 0), 0.07, skin, Finish.matte, scale: _v(0.6, 1, 0.8)));
    }
    final noseY = _FaceLayout.eyeY - 0.08 * layout.noseLength;
    face.shapes.add(SphereShape(_v(0, noseY, layout.depth(0, noseY, -0.003)), 0.035, _adjusted(skin, -0.06), Finish.matte,
        scale: _v(layout.noseWidth, layout.noseLength, 1)));
    for (final side in [-1.0, 1.0]) {
      face.shapes.add(SphereShape(_v(side * 0.2, -0.09, 0.3), 0.055, rgb(1, 0.45, 0.5), Finish.glow,
          scale: _v(1, 0.6, 0.3), opacity: 0.45));
    }
    _eyes(face, look, layout, skin, eyes);
    _brows(face, look, layout, skin);
    _mouth(face, layout);
    _hair(face, look);
    _glasses(face, look, layout);
    _hat(face, look);
  }

  static void _eyes(Node3D face, AvatarAppearance look, _FaceLayout layout, Color skin, List<Node3D> eyes) {
    for (final side in [-1.0, 1.0]) {
      final x = side * layout.eyeX;
      final socket = face.add(Node3D(position: _v(x, _FaceLayout.eyeY, layout.depth(x, _FaceLayout.eyeY, -0.018)), isEye: true));
      eyes.add(socket);
      final eye = socket.add(Node3D());
      eye.scale = _v(layout.eyeSize, layout.eyeSize, 1);
      eye.euler = _v(0, 0, side * layout.eyeTilt);
      if (look.eyes == Eyes.happy) {
        // Closed, smiling eyes: a little upside-down arc.
        eye.shapes.add(LineShape(_arc(_v(0, -0.02, 0.03), 0.05, 20, 160), 0.018, const Color(0xFF000000), Finish.glow));
        continue;
      }
      final open = (look.eyes == Eyes.sleepy ? 0.8 : 1.1) * layout.eyeOpen;
      eye.shapes.add(SphereShape(_v(0, 0, 0), 0.075, const Color(0xFFFFFFFF), Finish.matte, scale: _v(1, open, 0.5)));
      eye.shapes.add(SphereShape(_v(0, -0.005, 0.03), look.eyes == Eyes.sparkle ? 0.055 : 0.047, _irisColour(look), Finish.glossy,
          scale: _v(1, 1, 0.4)));
      eye.shapes.add(SphereShape(_v(0, -0.005, 0.045), 0.024, const Color(0xFF000000), Finish.glossy, scale: _v(1, 1, 0.4)));
      eye.shapes.add(SphereShape(_v(0.018, 0.02, 0.055), 0.013, const Color(0xFFFFFFFF), Finish.glow));
      if (look.eyes == Eyes.sparkle) {
        eye.shapes.add(SphereShape(_v(-0.018, -0.02, 0.056), 0.008, const Color(0xFFFFFFFF), Finish.glow));
      }
      if (look.eyes == Eyes.sleepy) {
        eye.shapes.add(SphereShape(_v(0, 0.035, 0.05), 0.08, skin, Finish.matte, scale: _v(1.05, 0.55, 0.6)));
      }
    }
  }

  static void _brows(Node3D face, AvatarAppearance look, _FaceLayout layout, Color skin) {
    final colour = look.hairStyle == HairStyle.none ? _adjusted(skin, -0.3) : _hairColour(look);
    for (final side in [-1.0, 1.0]) {
      // Positive tilts lift the outer end. A measured face brings its own slope.
      final tilt = look.brows == Brows.raised ? -0.25 : (layout.browTilt ?? -0.08);
      final x = side * layout.eyeX;
      // Bigger eyes push the brows up with them.
      final y = _FaceLayout.eyeY +
          (look.brows == Brows.raised ? 0.12 : 0.095) * layout.browGap +
          0.08 * (layout.eyeSize * layout.eyeOpen - 1);
      final z = layout.depth(x, y, 0.023);
      final half = 0.05 * layout.browLength + (look.brows == Brows.bold ? 0.018 : 0.011);
      // The outer end rises by `-tilt` (the brow is turned by side * tilt from horizontal).
      final dx = math.cos(side * tilt) * half, dy = math.sin(side * tilt) * half;
      face.shapes.add(CapsuleShape(_v(x - dx, y + dy, z), _v(x + dx, y - dy, z), look.brows == Brows.bold ? 0.018 : 0.011,
          colour, Finish.glow));
    }
  }

  static void _mouth(Node3D face, _FaceLayout layout) {
    final colour = layout.lips != null ? _adjusted(layout.lips!, -0.15) : rgb(0.55, 0.12, 0.15);
    final y = _FaceLayout.eyeY - 0.11 * layout.mouthDrop;
    face.shapes.add(LineShape(_arc(_v(0, y, layout.depth(0, y, 0.004)), 0.07 * layout.mouthWidth, 200, 340),
        0.02 * layout.lipHeight, colour, Finish.glow));
  }

  static void _hair(Node3D face, AvatarAppearance look) {
    if (look.hairStyle == HairStyle.none) return;
    final hair = _hairColour(look);
    // A cap set back and up from the head's centre: covers the top and back, leaves the face.
    face.shapes.add(SphereShape(_v(0, 0.07, -0.07), 0.375, hair, Finish.matte));
    switch (look.hairStyle) {
      case HairStyle.short:
      case HairStyle.none:
        break;
      case HairStyle.spiky:
        for (var i = 0; i < 7; i++) {
          final angle = i / 6 * math.pi - math.pi / 2;
          final base = _v(math.sin(angle) * 0.22, 0.36, math.cos(angle) * 0.08 - 0.08);
          final tip = base + _v(math.sin(angle) * 0.1, 0.18, -0.05);
          face.shapes.add(FrustumShape(base, tip, 0.08, 0.005, hair, Finish.matte));
        }
      case HairStyle.curly:
        for (var i = 0; i < 12; i++) {
          final angle = i / 12 * 2 * math.pi;
          face.shapes.add(SphereShape(
              _v(math.cos(angle) * 0.33, 0.2 + math.sin(angle * 2) * 0.03, math.sin(angle) * 0.3 - 0.06), 0.1, hair, Finish.matte));
        }
        face.shapes.add(SphereShape(_v(0, 0.4, -0.04), 0.14, hair, Finish.matte));
      case HairStyle.bob:
        face.shapes.add(SphereShape(_v(0, -0.02, -0.11), 0.39, hair, Finish.matte));
      case HairStyle.ponytail:
        face.shapes.add(CapsuleShape(_v(0, 0.2, -0.33), _v(0, -0.16, -0.47), 0.08, hair, Finish.matte));
        face.shapes.add(LineShape(_ring(_v(0, 0.2, -0.36), 0.07, tiltX: 0.4), 0.04, look.topColor.color, Finish.glossy, closed: true));
      case HairStyle.buns:
        for (final side in [-1.0, 1.0]) {
          face.shapes.add(SphereShape(_v(side * 0.24, 0.36, -0.04), 0.13, hair, Finish.matte));
        }
      case HairStyle.long:
        face.shapes.add(SphereShape(_v(0, -0.02, -0.11), 0.39, hair, Finish.matte));
        for (final side in [-1.0, 1.0]) {
          face.shapes.add(CapsuleShape(_v(side * 0.24, -0.1, -0.14), _v(side * 0.24, -0.5, -0.14), 0.1, hair, Finish.matte));
        }
    }
  }

  static void _glasses(Node3D face, AvatarAppearance look, _FaceLayout layout) {
    if (look.glasses == Glasses.none) return;
    final frame = look.glasses == Glasses.star ? rgb(1, 0.35, 0.6) : rgb(0.12, 0.12, 0.16);
    for (final side in [-1.0, 1.0]) {
      final c = _v(side * layout.eyeX, _FaceLayout.eyeY, 0.37);
      final points = switch (look.glasses) {
        Glasses.round || Glasses.none => _ring(c, 0.085, faceOn: true),
        Glasses.square => _roundedRect(c, 0.18, 0.144),
        Glasses.star => _star(c, 0.086, 0.043),
      };
      face.shapes.add(LineShape(points, 0.022, frame, Finish.glossy, closed: true));
    }
    final half = math.max(0.02, 2 * layout.eyeX - 0.18) / 2;
    face.shapes.add(LineShape([_v(-half, 0.05, 0.37), _v(half, 0.05, 0.37)], 0.02, frame, Finish.glossy));
  }

  static void _hat(Node3D face, AvatarAppearance look) {
    final colour = _adjusted(look.topColor.color, 0.1);
    switch (look.hat) {
      case Hat.none:
        return;
      case Hat.cap:
        face.shapes.add(SphereShape(_v(0, 0.2, -0.03), 0.39, colour, Finish.matte, scale: _v(1, 0.62, 1)));
        // The peak sticks out over the forehead.
        face.shapes.add(SphereShape(_v(0, 0.2, 0.34), 0.22, _adjusted(colour, -0.15), Finish.matte, scale: _v(0.95, 0.12, 0.75)));
      case Hat.beanie:
        face.shapes.add(SphereShape(_v(0, 0.2, -0.04), 0.395, colour, Finish.matte, scale: _v(1, 0.7, 1)));
        face.shapes.add(SphereShape(_v(0, 0.49, -0.04), 0.08, const Color(0xFFFFFFFF), Finish.matte));
      case Hat.crown:
        final gold = rgb(1, 0.8, 0.2);
        face.shapes.add(LineShape(_ring(_v(0, 0.42, -0.02), 0.22), 0.1, gold, Finish.glossy, closed: true));
        for (var i = 0; i < 5; i++) {
          final angle = i / 5 * 2 * math.pi;
          final base = _v(math.sin(angle) * 0.22, 0.46, math.cos(angle) * 0.22 - 0.02);
          face.shapes.add(FrustumShape(base, base + _v(0, 0.12, 0), 0.05, 0.004, gold, Finish.glossy));
        }
      case Hat.bow:
        final ribbon = rgb(1, 0.35, 0.55);
        for (final side in [-1.0, 1.0]) {
          face.shapes.add(SphereShape(_v(0.22 + side * 0.08, 0.34, 0.12), 0.08, ribbon, Finish.glossy, scale: _v(1.3, 0.8, 0.5)));
        }
        face.shapes.add(SphereShape(_v(0.22, 0.34, 0.15), 0.04, ribbon, Finish.glossy));
    }
  }

  // Outlines

  /// A circle around `c`: lying flat (axis up) unless `faceOn`, optionally tipped about x.
  static List<vm.Vector3> _ring(vm.Vector3 c, double r, {double tiltX = 0, double squashZ = 1, bool faceOn = false}) {
    final points = <vm.Vector3>[];
    for (var i = 0; i < 28; i++) {
      final a = i / 28 * 2 * math.pi;
      vm.Vector3 p = faceOn ? vm.Vector3(math.cos(a) * r, math.sin(a) * r, 0) : vm.Vector3(math.cos(a) * r, 0, math.sin(a) * r * squashZ);
      if (tiltX != 0) p = vm.Matrix3.rotationX(tiltX).transformed(p);
      points.add(c + p);
    }
    return points;
  }

  /// An arc facing the viewer, angles in degrees (0 = right, 90 = up).
  static List<vm.Vector3> _arc(vm.Vector3 c, double r, double from, double to) => [
        for (var i = 0; i <= 16; i++)
          () {
            final a = (from + (to - from) * i / 16) * math.pi / 180;
            return c + vm.Vector3(math.cos(a) * r, math.sin(a) * r, 0);
          }(),
      ];

  static List<vm.Vector3> _roundedRect(vm.Vector3 c, double w, double h) {
    final r = w * 0.2, points = <vm.Vector3>[];
    final corners = [(w / 2 - r, h / 2 - r, 0.0), (-(w / 2 - r), h / 2 - r, 90.0), (-(w / 2 - r), -(h / 2 - r), 180.0), (w / 2 - r, -(h / 2 - r), 270.0)];
    for (final (x, y, start) in corners) {
      for (var i = 0; i <= 4; i++) {
        final a = (start + 90 * i / 4) * math.pi / 180;
        points.add(c + vm.Vector3(x + math.cos(a) * r, y + math.sin(a) * r, 0));
      }
    }
    return points;
  }

  static List<vm.Vector3> _star(vm.Vector3 c, double outer, double inner) => [
        for (var i = 0; i < 10; i++)
          () {
            final r = i.isEven ? outer : inner;
            final a = i * math.pi / 5 + math.pi / 2;
            return c + vm.Vector3(math.cos(a) * r, math.sin(a) * r, 0);
          }(),
      ];

  // Colours (the exact sampled colour while the child keeps the matching swatch)

  static Color _skinColour(AvatarAppearance look) {
    final m = look.measured;
    if (m != null && m.skinMatch == look.skinTone) return m.skin.color;
    return look.skinTone.color;
  }

  static Color _hairColour(AvatarAppearance look) {
    final m = look.measured;
    if (m != null && m.hair != null && m.hairMatch == look.hairColor) return m.hair!.color;
    return look.hairColor.color;
  }

  static Color _irisColour(AvatarAppearance look) {
    final m = look.measured;
    if (m != null && m.iris != null && m.irisMatch == look.eyeColor) return m.iris!.color;
    return look.eyeColor.color;
  }

  /// Lighter (positive) or darker (negative).
  static Color _adjusted(Color c, double amount) {
    final hsv = _HSV.of(c);
    return _HSV(hsv.h, hsv.s, (hsv.v + amount).clamp(0, 1)).color;
  }

  /// A friendly contrasting colour (for the backpack).
  static Color _rotatedHue(Color c) {
    final hsv = _HSV.of(c);
    return _HSV((hsv.h + 0.45) % 1, math.max(hsv.s, 0.5), math.max(hsv.v, 0.7)).color;
  }
}

class _HSV {
  _HSV(this.h, this.s, this.v);
  final double h, s, v;

  factory _HSV.of(Color c) {
    final r = c.r, g = c.g, b = c.b;
    final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
    final d = mx - mn;
    double h = 0;
    if (d > 0) {
      if (mx == r) {
        h = ((g - b) / d) % 6;
      } else if (mx == g) {
        h = (b - r) / d + 2;
      } else {
        h = (r - g) / d + 4;
      }
      h /= 6;
      if (h < 0) h += 1;
    }
    return _HSV(h, mx == 0 ? 0 : d / mx, mx);
  }

  Color get color {
    final i = (h * 6).floor() % 6;
    final f = h * 6 - (h * 6).floor();
    final p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
    final (r, g, b) = switch (i) {
      0 => (v, t, p),
      1 => (q, v, p),
      2 => (p, v, t),
      3 => (p, q, v),
      4 => (t, p, v),
      _ => (v, p, q),
    };
    return Color.from(alpha: 1, red: r, green: g, blue: b);
  }
}
