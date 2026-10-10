// Polygon triangulation by ear clipping, adapted from Mapbox's earcut
// (ISC license, https://github.com/mapbox/earcut). It handles holes, and
// degenerate or slightly self-intersecting rings, which simplified map data
// produces. The z-order index of the original is left out: this runs
// offline, where O(n²) on a few thousand points is fine.

/// Triangulates a polygon given as flat x, y pairs. [holeIndices] are the
/// vertex indices where each hole ring starts. Returns vertex indices,
/// three per triangle.
List<int> earcut(List<double> data, [List<int> holeIndices = const []]) {
  final hasHoles = holeIndices.isNotEmpty;
  final outerLength = hasHoles ? holeIndices[0] * 2 : data.length;
  var outer = _linkedList(data, 0, outerLength, clockwise: true);
  final triangles = <int>[];
  if (outer == null || outer.next == outer.prev) return triangles;
  if (hasHoles) outer = _eliminateHoles(data, holeIndices, outer);
  _earcutLinked(outer, triangles, 0);
  return triangles;
}

class _Node {
  _Node(this.i, this.x, this.y);

  /// Vertex index in the input.
  final int i;
  final double x;
  final double y;
  late _Node prev;
  late _Node next;
  bool steiner = false;
}

_Node? _linkedList(
  List<double> data,
  int start,
  int end, {
  required bool clockwise,
}) {
  _Node? last;
  if (clockwise == (_signedArea(data, start, end) > 0)) {
    for (var i = start; i < end; i += 2) {
      last = _insert(i ~/ 2, data[i], data[i + 1], last);
    }
  } else {
    for (var i = end - 2; i >= start; i -= 2) {
      last = _insert(i ~/ 2, data[i], data[i + 1], last);
    }
  }
  if (last != null && _equals(last, last.next)) {
    _remove(last);
    last = last.next;
  }
  return last;
}

_Node? _filterPoints(_Node? start, [_Node? end]) {
  if (start == null) return start;
  end ??= start;
  var p = start;
  bool again;
  do {
    again = false;
    if (!p.steiner && (_equals(p, p.next) || _area(p.prev, p, p.next) == 0)) {
      _remove(p);
      p = end = p.prev;
      if (p == p.next) break;
      again = true;
    } else {
      p = p.next;
    }
  } while (again || p != end);
  return end;
}

void _earcutLinked(_Node? ear, List<int> triangles, int pass) {
  if (ear == null) return;
  var stop = ear;
  while (ear!.prev != ear.next) {
    final prev = ear.prev;
    final next = ear.next;
    if (_isEar(ear)) {
      triangles
        ..add(prev.i)
        ..add(ear.i)
        ..add(next.i);
      _remove(ear);
      ear = next.next;
      stop = next.next;
      continue;
    }
    ear = next;
    if (ear == stop) {
      // No ear found: clean up and retry, then cure self-intersections,
      // then split the polygon in two.
      if (pass == 0) {
        _earcutLinked(_filterPoints(ear), triangles, 1);
      } else if (pass == 1) {
        final cured = _cureLocalIntersections(_filterPoints(ear)!, triangles);
        _earcutLinked(cured, triangles, 2);
      } else {
        _splitEarcut(ear, triangles);
      }
      break;
    }
  }
}

bool _isEar(_Node ear) {
  final a = ear.prev, b = ear, c = ear.next;
  if (_area(a, b, c) >= 0) return false; // Reflex: not an ear.
  final x0 = _min3(a.x, b.x, c.x), x1 = _max3(a.x, b.x, c.x);
  final y0 = _min3(a.y, b.y, c.y), y1 = _max3(a.y, b.y, c.y);
  var p = c.next;
  while (p != a) {
    if (p.x >= x0 &&
        p.x <= x1 &&
        p.y >= y0 &&
        p.y <= y1 &&
        _pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) &&
        _area(p.prev, p, p.next) >= 0) {
      return false;
    }
    p = p.next;
  }
  return true;
}

_Node? _cureLocalIntersections(_Node start, List<int> triangles) {
  var p = start;
  do {
    final a = p.prev, b = p.next.next;
    if (!_equals(a, b) &&
        _intersects(a, p, p.next, b) &&
        _locallyInside(a, b) &&
        _locallyInside(b, a)) {
      triangles
        ..add(a.i)
        ..add(p.i)
        ..add(b.i);
      _remove(p);
      _remove(p.next);
      p = start = b;
    }
    p = p.next;
  } while (p != start);
  return _filterPoints(p);
}

void _splitEarcut(_Node start, List<int> triangles) {
  var a = start;
  do {
    var b = a.next.next;
    while (b != a.prev) {
      if (a.i != b.i && _isValidDiagonal(a, b)) {
        var c = _splitPolygon(a, b);
        final first = _filterPoints(a, a.next);
        c = _filterPoints(c, c.next)!;
        _earcutLinked(first, triangles, 0);
        _earcutLinked(c, triangles, 0);
        return;
      }
      b = b.next;
    }
    a = a.next;
  } while (a != start);
}

_Node _eliminateHoles(List<double> data, List<int> holeIndices, _Node outer) {
  final queue = <_Node>[];
  for (var i = 0; i < holeIndices.length; i++) {
    final start = holeIndices[i] * 2;
    final end = i < holeIndices.length - 1
        ? holeIndices[i + 1] * 2
        : data.length;
    final list = _linkedList(data, start, end, clockwise: false);
    if (list == null) continue;
    if (list == list.next) list.steiner = true;
    queue.add(_leftmost(list));
  }
  queue.sort((a, b) => a.x.compareTo(b.x));
  for (final hole in queue) {
    outer = _eliminateHole(hole, outer);
  }
  return outer;
}

_Node _eliminateHole(_Node hole, _Node outer) {
  final bridge = _findHoleBridge(hole, outer);
  if (bridge == null) return outer;
  final bridgeReverse = _splitPolygon(bridge, hole);
  _filterPoints(bridgeReverse, bridgeReverse.next);
  return _filterPoints(bridge, bridge.next)!;
}

/// Finds a vertex of the outer ring visible from the hole's leftmost
/// point, to cut a bridge through.
_Node? _findHoleBridge(_Node hole, _Node outer) {
  var p = outer;
  final hx = hole.x, hy = hole.y;
  var qx = double.negativeInfinity;
  _Node? m;
  do {
    if (hy <= p.y && hy >= p.next.y && p.next.y != p.y) {
      final x = p.x + (hy - p.y) * (p.next.x - p.x) / (p.next.y - p.y);
      if (x <= hx && x > qx) {
        qx = x;
        m = p.x < p.next.x ? p : p.next;
        if (x == hx) return m;
      }
    }
    p = p.next;
  } while (p != outer);
  if (m == null) return null;

  final stop = m;
  final mx = m.x, my = m.y;
  var tanMin = double.infinity;
  p = m;
  do {
    if (hx >= p.x &&
        p.x >= mx &&
        hx != p.x &&
        _pointInTriangle(
          hy < my ? hx : qx,
          hy,
          mx,
          my,
          hy < my ? qx : hx,
          hy,
          p.x,
          p.y,
        )) {
      final tan = (hy - p.y).abs() / (hx - p.x);
      if (_locallyInside(p, hole) &&
          (tan < tanMin ||
              (tan == tanMin &&
                  (p.x > m!.x ||
                      (p.x == m.x && _sectorContainsSector(m, p)))))) {
        m = p;
        tanMin = tan;
      }
    }
    p = p.next;
  } while (p != stop);
  return m;
}

bool _sectorContainsSector(_Node m, _Node p) =>
    _area(m.prev, m, p.prev) < 0 && _area(p.next, m, m.next) < 0;

_Node _leftmost(_Node start) {
  var p = start, leftmost = start;
  do {
    if (p.x < leftmost.x || (p.x == leftmost.x && p.y < leftmost.y)) {
      leftmost = p;
    }
    p = p.next;
  } while (p != start);
  return leftmost;
}

bool _pointInTriangle(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
  double px,
  double py,
) =>
    (cx - px) * (ay - py) >= (ax - px) * (cy - py) &&
    (ax - px) * (by - py) >= (bx - px) * (ay - py) &&
    (bx - px) * (cy - py) >= (cx - px) * (by - py);

bool _isValidDiagonal(_Node a, _Node b) =>
    a.next.i != b.i &&
    a.prev.i != b.i &&
    !_intersectsPolygon(a, b) &&
    ((_locallyInside(a, b) &&
            _locallyInside(b, a) &&
            _middleInside(a, b) &&
            (_area(a.prev, a, b.prev) != 0 || _area(a, b.prev, b) != 0)) ||
        (_equals(a, b) &&
            _area(a.prev, a, a.next) > 0 &&
            _area(b.prev, b, b.next) > 0));

/// Twice the signed area of triangle p, q, r.
double _area(_Node p, _Node q, _Node r) =>
    (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);

bool _equals(_Node a, _Node b) => a.x == b.x && a.y == b.y;

bool _intersects(_Node p1, _Node q1, _Node p2, _Node q2) {
  final o1 = _area(p1, q1, p2).sign;
  final o2 = _area(p1, q1, q2).sign;
  final o3 = _area(p2, q2, p1).sign;
  final o4 = _area(p2, q2, q1).sign;
  if (o1 != o2 && o3 != o4) return true;
  if (o1 == 0 && _onSegment(p1, p2, q1)) return true;
  if (o2 == 0 && _onSegment(p1, q2, q1)) return true;
  if (o3 == 0 && _onSegment(p2, p1, q2)) return true;
  if (o4 == 0 && _onSegment(p2, q1, q2)) return true;
  return false;
}

bool _onSegment(_Node p, _Node q, _Node r) =>
    q.x <= (p.x > r.x ? p.x : r.x) &&
    q.x >= (p.x < r.x ? p.x : r.x) &&
    q.y <= (p.y > r.y ? p.y : r.y) &&
    q.y >= (p.y < r.y ? p.y : r.y);

bool _intersectsPolygon(_Node a, _Node b) {
  var p = a;
  do {
    if (p.i != a.i &&
        p.next.i != a.i &&
        p.i != b.i &&
        p.next.i != b.i &&
        _intersects(p, p.next, a, b)) {
      return true;
    }
    p = p.next;
  } while (p != a);
  return false;
}

bool _locallyInside(_Node a, _Node b) => _area(a.prev, a, a.next) < 0
    ? _area(a, b, a.next) >= 0 && _area(a, a.prev, b) >= 0
    : _area(a, b, a.prev) < 0 || _area(a, a.next, b) < 0;

bool _middleInside(_Node a, _Node b) {
  var p = a;
  var inside = false;
  final px = (a.x + b.x) / 2, py = (a.y + b.y) / 2;
  do {
    if (((p.y > py) != (p.next.y > py)) &&
        p.next.y != p.y &&
        (px < (p.next.x - p.x) * (py - p.y) / (p.next.y - p.y) + p.x)) {
      inside = !inside;
    }
    p = p.next;
  } while (p != a);
  return inside;
}

/// Links a with b by a diagonal, splitting the ring in two. Returns the
/// copy of b that starts the second ring.
_Node _splitPolygon(_Node a, _Node b) {
  final a2 = _Node(a.i, a.x, a.y), b2 = _Node(b.i, b.x, b.y);
  final an = a.next, bp = b.prev;
  a.next = b;
  b.prev = a;
  a2.next = an;
  an.prev = a2;
  b2.next = a2;
  a2.prev = b2;
  bp.next = b2;
  b2.prev = bp;
  return b2;
}

_Node _insert(int i, double x, double y, _Node? last) {
  final p = _Node(i, x, y);
  if (last == null) {
    p.prev = p;
    p.next = p;
  } else {
    p.next = last.next;
    p.prev = last;
    last.next.prev = p;
    last.next = p;
  }
  return p;
}

void _remove(_Node p) {
  p.next.prev = p.prev;
  p.prev.next = p.next;
}

double _signedArea(List<double> data, int start, int end) {
  var sum = 0.0;
  for (var i = start, j = end - 2; i < end; i += 2) {
    sum += (data[j] - data[i]) * (data[i + 1] + data[j + 1]);
    j = i;
  }
  return sum;
}

double _min3(double a, double b, double c) =>
    a < b ? (a < c ? a : c) : (b < c ? b : c);

double _max3(double a, double b, double c) =>
    a > b ? (a > c ? a : c) : (b > c ? b : c);
