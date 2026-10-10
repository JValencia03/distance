// Generates the app's Lottie animations in assets/lottie/.
//
// Run from frontend/:  dart run tool/generate_lottie.dart
//
// Lottie files are JSON; writing them from code keeps them reviewable and
// easy to tweak (colors, timing) without an animation editor. Every shape
// follows the "pastel clay" look: a solid fill, a soft white highlight and a
// faint shadow below.
import 'dart:convert';
import 'dart:io';

void main() {
  final animations = {
    'loading': _loading(),
    'empty': _empty(),
    'error': _error(),
    'success': _success(),
  };
  for (final MapEntry(key: name, value: animation) in animations.entries) {
    final file = File('assets/lottie/$name.json')..createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(animation));
    stdout.writeln('wrote ${file.path}');
  }
}

// Palette (sRGB, 0–1), matching lib/shared/theme.dart.
const _lavender = [0.627, 0.549, 0.961];
const _lavenderLight = [0.788, 0.741, 0.961];
const _peach = [1.0, 0.651, 0.553];
const _mint = [0.561, 0.847, 0.765];
const _mintDeep = [0.302, 0.749, 0.624];
const _sky = [0.663, 0.812, 1.0];
const _plum = [0.176, 0.141, 0.2];
const _cream = [1.0, 0.973, 0.953];
const _white = [1.0, 1.0, 1.0];

/// 0.5 s at 60 fps is 30 frames.
const _fps = 60;

// ---------------------------------------------------------------------------
// Animations

/// Three clay balls bouncing in a wave, with squash and stretch. Loops.
Map<String, Object?> _loading() {
  const end = 72;
  final layers = <Map<String, Object?>>[];
  final colors = [_lavender, _peach, _mint];
  for (var i = 0; i < 3; i++) {
    final x = 60.0 + i * 40;
    final p = i * 12; // phase
    // Ball anchored at its bottom, so squashing keeps it on the ground.
    layers.add(
      _layer(
        name: 'ball $i',
        position: _animated([
          _key(0, [x, 132]),
          _key(p, [x, 132], ease: _easeOut),
          _key(p + 18, [x, 100], ease: _easeIn),
          _key(p + 36, [x, 132]),
          _key(end, [x, 132]),
        ]),
        scale: _animated([
          _key(0, [100, 100]),
          _key(p, [100, 100]),
          _key(p + 4, [94, 106]),
          _key(p + 18, [100, 100]),
          _key(p + 33, [96, 104]),
          _key(p + 36, [116, 86]),
          _key(p + 42, [100, 100]),
          _key(end, [100, 100]),
        ]),
        shapes: _clayBall(colors[i], radius: 18, offsetY: -18),
        end: end,
      ),
    );
    // Shadow: shrinks and fades while the ball is up.
    layers.add(
      _layer(
        name: 'shadow $i',
        position: _static([x, 136]),
        scale: _animated([
          _key(0, [100, 100]),
          _key(p, [100, 100], ease: _easeOut),
          _key(p + 18, [60, 60], ease: _easeIn),
          _key(p + 36, [100, 100]),
          _key(end, [100, 100]),
        ]),
        shapes: [
          _ellipseGroup(size: [34, 8], color: _lavender, opacity: 30),
        ],
        end: end,
      ),
    );
  }
  // Shapes drawn first end up below: put shadows at the bottom.
  return _animation('loading', end, [
    ...layers.where((l) => (l['nm'] as String).startsWith('ball')),
    ...layers.where((l) => (l['nm'] as String).startsWith('shadow')),
  ]);
}

/// A map pin hopping in place with twinkling sparkles: "nothing here yet,
/// be the first". Loops.
Map<String, Object?> _empty() {
  const end = 120;
  final hop = <Map<String, Object?>>[];
  final squash = <Map<String, Object?>>[];
  final shadow = <Map<String, Object?>>[];
  for (final start in [0, 60]) {
    hop.addAll([
      _key(start, [100, 152], ease: _easeOut),
      _key(start + 24, [100, 116], ease: _easeIn),
      _key(start + 48, [100, 152]),
    ]);
    squash.addAll([
      _key(start, [108, 92]),
      _key(start + 8, [95, 106]),
      _key(start + 24, [100, 100]),
      _key(start + 44, [97, 103]),
      _key(start + 48, [110, 90]),
      _key(start + 54, [104, 96]),
    ]);
    shadow.addAll([
      _key(start, [100, 100], ease: _easeOut),
      _key(start + 24, [60, 60], ease: _easeIn),
      _key(start + 48, [100, 100]),
    ]);
  }
  hop.add(_key(end, [100, 152]));
  squash.add(_key(end, [108, 92]));
  shadow.add(_key(end, [100, 100]));

  final pin = [
    // Highlight and hole first: earlier shapes are drawn on top.
    _ellipseGroup(
      size: [14, 9],
      color: _white,
      opacity: 60,
      position: [-13, -78],
    ),
    _ellipseGroup(size: [22, 22], color: _cream, position: [0, -62]),
    _group([
      _path([
        [-26, -48],
        [26, -48],
        [0, 0],
      ], closed: true),
      _fill(_peach),
    ]),
    _ellipseGroup(size: [60, 60], color: _peach, position: [0, -62]),
  ];

  return _animation('empty', end, [
    _sparkle(position: [46, 64], color: _lavender, delay: 0, end: end),
    _sparkle(position: [158, 50], color: _mint, delay: 30, end: end),
    _sparkle(position: [162, 118], color: _peach, delay: 64, end: end),
    _layer(
      name: 'pin',
      position: _animated(hop),
      scale: _animated(squash),
      shapes: pin,
      end: end,
    ),
    _layer(
      name: 'shadow',
      position: _static([100, 156]),
      scale: _animated(shadow),
      shapes: [
        _ellipseGroup(size: [52, 12], color: _lavender, opacity: 30),
      ],
      end: end,
    ),
  ]);
}

/// A sad little cloud floating while it drizzles. Loops.
Map<String, Object?> _error() {
  const end = 120;
  final cloud = [
    // Face.
    _group([
      _path(
        [
          [-7, 24],
          [9, 24],
        ],
        outTangents: [
          [4, -5],
          [0, 0],
        ],
        inTangents: [
          [0, 0],
          [-4, -5],
        ],
      ),
      _stroke(_plum, width: 3),
    ]),
    _ellipseGroup(size: [7, 7], color: _plum, position: [-10, 10]),
    _ellipseGroup(size: [7, 7], color: _plum, position: [12, 10]),
    // Highlight.
    _ellipseGroup(
      size: [28, 12],
      color: _white,
      opacity: 55,
      position: [-2, -30],
    ),
    // Body: three puffs over a rounded base.
    _ellipseGroup(size: [52, 52], color: _lavenderLight, position: [-28, 4]),
    _ellipseGroup(size: [68, 68], color: _lavenderLight, position: [6, -12]),
    _ellipseGroup(size: [44, 44], color: _lavenderLight, position: [36, 6]),
    _group([
      {
        'ty': 'rc',
        'd': 1,
        'p': _static([3, 18]),
        's': _static([112, 28]),
        'r': _static(14),
      },
      _fill(_lavenderLight),
    ]),
  ];

  final drops = <Map<String, Object?>>[];
  // Each drop falls for 30 frames; start frames chosen so the loop is
  // seamless (every drop is invisible at frames 0 and 120).
  final schedule = {
    78.0: [0, 40, 80],
    104.0: [15, 55, 90],
    128.0: [28, 68],
  };
  for (final MapEntry(key: x, value: starts) in schedule.entries) {
    final position = <Map<String, Object?>>[
      _key(0, [x, 120]),
    ];
    final opacity = <Map<String, Object?>>[_key(0, 0)];
    for (final start in starts) {
      position.addAll([
        _key(start, [x, 120], ease: _easeIn),
        _key(start + 30, [x, 168]),
      ]);
      opacity.addAll([
        _key(start, 0),
        _key(start + 5, 90),
        _key(start + 22, 90),
        _key(start + 30, 0),
      ]);
    }
    position.add(_key(end, [x, 120]));
    opacity.add(_key(end, 0));
    drops.add(
      _layer(
        name: 'drop',
        position: _animated(position),
        opacity: _animated(opacity),
        shapes: [
          _ellipseGroup(size: [9, 14], color: _sky),
        ],
        end: end,
      ),
    );
  }

  return _animation('error', end, [
    _layer(
      name: 'cloud',
      position: _animated([
        _key(0, [100, 82], ease: _easeInOut),
        _key(60, [100, 92], ease: _easeInOut),
        _key(end, [100, 82]),
      ]),
      rotation: _animated([
        _key(0, -2, ease: _easeInOut),
        _key(60, 2, ease: _easeInOut),
        _key(end, -2),
      ]),
      shapes: cloud,
      end: end,
    ),
    ...drops,
  ]);
}

/// A mint badge pops in with a ring burst and a check that draws itself.
/// Plays once; the last frame is the finished badge.
Map<String, Object?> _success() {
  const end = 72;
  const center = [100.0, 100.0];
  final dots = <Map<String, Object?>>[];
  final dotColors = [_lavender, _peach, _mint];
  for (var i = 0; i < 6; i++) {
    final angle = i * 60.0;
    dots.add(
      _layer(
        name: 'dot $i',
        position: _static(center),
        rotation: _static(angle),
        scale: _animated([
          _key(0, [0, 0]),
          _key(8, [100, 100]),
          _key(40, [0, 0]),
          _key(end, [0, 0]),
        ]),
        // The dot travels outwards inside the rotated layer.
        shapes: [
          _group(
            [
              {
                'ty': 'el',
                'd': 1,
                'p': _static([0, 0]),
                's': _static([12, 12]),
              },
              _fill(dotColors[i % 3]),
            ],
            position: _animated([
              _key(0, [0, -44], ease: _easeOut),
              _key(40, [0, -88]),
            ]),
          ),
        ],
        end: end,
      ),
    );
  }

  return _animation('success', end, [
    _layer(
      name: 'check',
      position: _static(center),
      shapes: [
        _group([
          _path([
            [-20, 2],
            [-6, 16],
            [22, -14],
          ]),
          {
            'ty': 'tm',
            'm': 1,
            's': _static(0),
            'o': _static(0),
            'e': _animated([
              _key(0, 0),
              _key(16, 0, ease: _easeOut),
              _key(34, 100),
            ]),
          },
          _stroke(_white, width: 12),
        ]),
      ],
      end: end,
    ),
    _layer(
      name: 'badge',
      position: _static(center),
      scale: _animated([
        _key(0, [0, 0], ease: _easeOut),
        _key(14, [118, 118]),
        _key(22, [94, 94]),
        _key(28, [104, 104]),
        _key(34, [100, 100]),
      ]),
      shapes: _clayBall(_mintDeep, radius: 46),
      end: end,
    ),
    _layer(
      name: 'ring',
      position: _static(center),
      scale: _animated([
        _key(0, [40, 40]),
        _key(6, [40, 40], ease: _easeOut),
        _key(36, [150, 150]),
      ]),
      opacity: _animated([_key(0, 0), _key(6, 100), _key(36, 0)]),
      shapes: [
        _group([
          {
            'ty': 'el',
            'd': 1,
            'p': _static([0, 0]),
            's': _static([110, 110]),
          },
          _stroke(_mint, width: 6),
        ]),
      ],
      end: end,
    ),
    ...dots,
  ]);
}

// ---------------------------------------------------------------------------
// Building blocks

/// A clay ball: highlight, body and nothing else (shadows are separate
/// layers so they do not squash).
List<Map<String, Object?>> _clayBall(
  List<double> color, {
  required double radius,
  double offsetY = 0,
}) => [
  _ellipseGroup(
    size: [radius * 0.7, radius * 0.45],
    color: _white,
    opacity: 55,
    position: [-radius * 0.32, offsetY - radius * 0.4],
  ),
  _ellipseGroup(
    size: [radius * 2, radius * 2],
    color: color,
    position: [0, offsetY],
  ),
];

/// A four-point star that twinkles once per loop.
Map<String, Object?> _sparkle({
  required List<double> position,
  required List<double> color,
  required int delay,
  required int end,
}) => _layer(
  name: 'sparkle',
  position: _static(position),
  scale: _animated([
    _key(0, [0, 0]),
    _key(delay, [0, 0], ease: _easeOut),
    _key(delay + 14, [110, 110], ease: _easeInOut),
    _key(delay + 34, [0, 0]),
    _key(end, [0, 0]),
  ]),
  rotation: _animated([
    _key(0, 0),
    _key(delay, 0),
    _key(delay + 34, 90),
    _key(end, 90),
  ]),
  shapes: [
    _group([
      _path([
        [0, -18],
        [4, -4],
        [18, 0],
        [4, 4],
        [0, 18],
        [-4, 4],
        [-18, 0],
        [-4, -4],
      ], closed: true),
      _fill(color),
    ]),
  ],
  end: end,
);

Map<String, Object?> _animation(
  String name,
  int end,
  List<Map<String, Object?>> layers,
) => {
  'v': '5.7.4',
  'nm': name,
  'fr': _fps,
  'ip': 0,
  'op': end,
  'w': 200,
  'h': 200,
  'ddd': 0,
  'assets': <Object>[],
  'layers': [
    for (final (index, layer) in layers.indexed) {...layer, 'ind': index + 1},
  ],
};

Map<String, Object?> _layer({
  required String name,
  required Map<String, Object?> position,
  Map<String, Object?>? scale,
  Map<String, Object?>? rotation,
  Map<String, Object?>? opacity,
  required List<Map<String, Object?>> shapes,
  required int end,
}) => {
  'ddd': 0,
  'ty': 4,
  'nm': name,
  'sr': 1,
  'ks': {
    'o': opacity ?? _static(100),
    'r': rotation ?? _static(0),
    'p': position,
    'a': _static([0, 0, 0]),
    's': scale ?? _static([100, 100]),
  },
  'ao': 0,
  'shapes': shapes,
  'ip': 0,
  'op': end,
  'st': 0,
  'bm': 0,
};

Map<String, Object?> _group(
  List<Map<String, Object?>> items, {
  Map<String, Object?>? position,
}) => {
  'ty': 'gr',
  'it': [
    ...items,
    {
      'ty': 'tr',
      'p': position ?? _static([0, 0]),
      'a': _static([0, 0]),
      's': _static([100, 100]),
      'r': _static(0),
      'o': _static(100),
    },
  ],
};

Map<String, Object?> _ellipseGroup({
  required List<double> size,
  required List<double> color,
  double opacity = 100,
  List<double> position = const [0, 0],
}) => _group([
  {'ty': 'el', 'd': 1, 'p': _static(position), 's': _static(size)},
  _fill(color, opacity: opacity),
]);

Map<String, Object?> _path(
  List<List<double>> vertices, {
  bool closed = false,
  List<List<double>>? inTangents,
  List<List<double>>? outTangents,
}) {
  final zero = [
    for (final _ in vertices) [0.0, 0.0],
  ];
  return {
    'ty': 'sh',
    'ks': _static({
      'v': vertices,
      'i': inTangents ?? zero,
      'o': outTangents ?? zero,
      'c': closed,
    }),
  };
}

Map<String, Object?> _fill(List<double> color, {double opacity = 100}) => {
  'ty': 'fl',
  'c': _static([...color, 1]),
  'o': _static(opacity),
  'r': 1,
};

Map<String, Object?> _stroke(List<double> color, {required double width}) => {
  'ty': 'st',
  'c': _static([...color, 1]),
  'o': _static(100),
  'w': _static(width),
  'lc': 2, // round cap
  'lj': 2, // round join
};

Map<String, Object?> _static(Object value) => {'a': 0, 'k': value};

/// Keyframes must have increasing frames: when two share a frame (e.g. a
/// phase of 0), the later one wins.
Map<String, Object?> _animated(List<Map<String, Object?>> keyframes) {
  final unique = <Map<String, Object?>>[];
  for (final keyframe in keyframes) {
    if (unique.isNotEmpty && unique.last['t'] == keyframe['t']) {
      unique.removeLast();
    }
    unique.add(keyframe);
  }
  return {'a': 1, 'k': unique};
}

/// Cubic bezier easing as Lottie stores it: the out handle of this keyframe
/// and the in handle of the next.
typedef _Ease = ({double ox, double oy, double ix, double iy});

const _Ease _linear = (ox: 0, oy: 0, ix: 1, iy: 1);
const _Ease _easeOut = (ox: 0.2, oy: 0.6, ix: 0.4, iy: 1);
const _Ease _easeIn = (ox: 0.6, oy: 0, ix: 0.8, iy: 0.4);
const _Ease _easeInOut = (ox: 0.45, oy: 0, ix: 0.55, iy: 1);

/// Keyframe at [frame]; [ease] shapes the motion towards the next one.
Map<String, Object?> _key(int frame, Object value, {_Ease ease = _linear}) => {
  't': frame,
  's': value is List ? value : [value],
  'o': {
    'x': [ease.ox],
    'y': [ease.oy],
  },
  'i': {
    'x': [ease.ix],
    'y': [ease.iy],
  },
};
