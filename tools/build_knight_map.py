#!/usr/bin/env python3
"""Build the playable R13 test profile from the manually reviewed R12 trace.

Standard-library only. Geometry and frontage are explicit; no target node count
is used to synthesize roads. --check verifies byte-for-byte reproducibility.
"""
from __future__ import annotations

import argparse
from collections import Counter, deque
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRACE = ROOT / "data/maps/knight_manor.trace.json"
OUTPUT = ROOT / "data/maps/knight_manor.json"
SCALE = 4
OFFSET = (8, 16)
SIZE = (97, 89)

# Rounded lot shapes in K1/K2 all lie on the -a or -b side of their road.
# Explicit groups make a source-trace change fail instead of silently assigning
# arbitrary sides. These are frontage coordinates, not building centers.
SMALL_SIDE_GROUPS = [
    ("-a", [(0, b) for b in range(1, 4)]),
    ("-b", [(a, 0) for a in range(2, 5)]),
    ("-b", [(9, 0), (10, 0)]),
    ("-a", [(2, b) for b in range(5, 8)]),
    ("-b", [(a, 8) for a in range(3, 6)]),
    ("-a", [(5, 9), (5, 10)]),
    ("-b", [(a, 10) for a in range(7, 10)]),
    ("-a", [(11, b) for b in range(12, 17)]),
    ("-b", [(a, 17) for a in range(13, 17)]),
    ("-a", [(19, 12), (19, 13)]),
    ("-a", [(20, b) for b in range(8, 12)]),
    ("-a", [(21, b) for b in range(3, 7)]),
    ("-a", [(20, -1)]),
    ("-a", [(20, 2)]),
    ("-b", [(a, -2) for a in range(12, 16)]),
    ("-b", [(a, -2) for a in range(17, 21)]),
    ("-a", [(12, b) for b in range(1, 4)]),
    ("-a", [(13, b) for b in range(4, 7)]),
    ("-b", [(a, 7) for a in range(15, 19)]),
]


def cell(point):
    return [OFFSET[0] + SCALE * point[0], OFFSET[1] + SCALE * point[1]]


def contains(rect, point):
    x, y, w, h = rect
    return x <= point[0] < x + w and y <= point[1] < y + h


def overlaps(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def adjacent(point, rect):
    x, y, w, h = rect
    px, py = point
    return (x <= px < x + w and py in (y - 1, y + h)) or (y <= py < y + h and px in (x - 1, x + w))


def make_footprint(points, side, large=False):
    cells = [cell(p) for p in points]
    xs, ys = [p[0] for p in cells], [p[1] for p in cells]
    depth = 4 if large else 3
    if side == "-a":
        assert len(set(xs)) == 1
        return [xs[0] - depth, min(ys) - 1, depth, max(ys) - min(ys) + 3]
    assert side == "-b" and len(set(ys)) == 1
    return [min(xs) - 1, ys[0] - depth, max(xs) - min(xs) + 3, depth]


def build(trace, trace_sha):
    nodes = trace["nodes"]
    ids = {n["id"]: str(i) for i, n in enumerate(nodes)}
    by_coord = {tuple(n["logical_candidate"]): ids[n["id"]] for n in nodes}
    coords = {n["id"]: tuple(n["logical_candidate"]) for n in nodes}
    roads = []
    for n in nodes:
        visual = n["visual"]
        kind, name = "road", "道路"
        if visual.startswith("cash_"):
            kind, name = "cash", "现金 %+d" % n["printed_cash"]
        elif visual == "purple_pentagram":
            kind, name = "magic", "魔法屋"
        elif visual == "red_exclamation":
            kind, name = "news", "新闻格（内容待还原）"
        elif visual == "blue_numbered_balls":
            kind, name = "lottery", "乐透"
        elif visual == "blue_gamepad":
            kind, name = "minigame", "小游戏（内容待还原）"
        elif visual == "yellow_pig_like":
            kind, name = "unresolved", "黄色图标（待核实）"
        elif visual == "cyan_heart":
            name = "医院门前"
        elif visual == "gray_bars":
            name = "监狱门前"
        elif visual == "blue_card_rectangle":
            name = "银行门前"
        elif visual == "cyan_storefront":
            name = "商店门前"
        road = {
            "id": ids[n["id"]], "trace_id": n["id"],
            "trace_coord": n["logical_candidate"], "cell": cell(n["logical_candidate"]),
            "exits": [ids[v] for v in n["neighbors"]],
            "kind": kind, "name": name, "signal": False, "event_ids": [],
            "source_refs": n["source_refs"],
        }
        if kind == "cash":
            road["cash_amount"] = n["printed_cash"]
        roads.append(road)

    sides, streets = {}, {}
    for i, (side, points) in enumerate(SMALL_SIDE_GROUPS, 1):
        for point in points:
            assert point not in sides
            sides[point] = side
            streets[point] = "TEST-R13-street-%02d" % i
    lots = []
    small_seen = set()
    for prop in trace["properties"]:
        points = [coords[n] for n in prop["adjacent_road_nodes"]]
        large = prop["kind_candidate"] == "large"
        if large:
            assert len(points) == 2
            side = "-a" if points[0][0] == points[1][0] else "-b"
            street = "TEST-R13-large-" + prop["id"]
        else:
            assert len(points) == 1
            side, street = sides[points[0]], streets[points[0]]
            small_seen.add(points[0])
        lots.append({
            "id": prop["id"], "name": ("大型地块 " if large else "住宅地块 ") + prop["id"][2:],
            "kind": "large" if large else "small", "building_type": "vacant", "owner": -1, "level": 0,
            "footprint": make_footprint(points, side, large),
            "frontage_nodes": [ids[n] for n in prop["adjacent_road_nodes"]],
            "trigger_events": ["stop"], "rule_id": "TEST-R13-PROPERTY",
            "price": 12000 if large else 2400, "rent": 1800 if large else 360,
            "street_id": street, "trace_property_id": prop["id"], "trace_frontage": [list(p) for p in points],
            "plot_side": side, "side_evidence": ["K1", "K2"],
            "source_refs": prop["source_refs"],
            "entrance_profile": "TEST-R13: both entrances share one title and stop trigger; original trigger equivalence U" if large else "single frontage",
        })
    assert small_seen == set(sides), "Unassigned or stale manually reviewed small-lot side"

    # Roadside facility models are deliberately a display/test representation.
    # Their road identity is sourced; exact footprint dimensions are not original art.
    facility_specs = [
        ("bank_north", "bank", "北侧银行", (5, 0), "-b"),
        ("bank_west", "bank", "西侧银行", (11, 11), "-a"),
        ("bank_east", "bank", "东侧银行", (21, 2), "+a"),
        ("shop_north", "shop", "北侧商店", (1, 4), "-b"),
        ("shop_south", "shop", "南侧商店", (20, 7), "-b_shift"),
        ("hospital", "hospital", "医院", (0, 8), "-a"),
        ("prison", "prison", "监狱", (0, -2), "-b"),
    ]
    for suffix, kind, name, point, side in facility_specs:
        px, py = cell(point)
        if side == "+a":
            footprint = [px + 1, py - 1, 3, 3]
        elif side == "-b_shift":
            footprint = [px - 2, py - 3, 3, 3]
        else:
            footprint = make_footprint([point], side)
        lot = {
            "id": "facility_" + suffix, "kind": "facility", "building_type": kind,
            "name": name, "owner": -1, "level": 0, "footprint": footprint,
            "frontage_nodes": [by_coord[point]], "trigger_events": ["pass", "stop"] if kind == "bank" else ["stop"],
            "rule_id": "TEST-R13-FACILITY", "price": 0, "rent": 0,
            "street_id": "TEST-R13-facility-" + suffix,
            "trace_frontage": [list(point)], "plot_side": side,
            "footprint_profile": "TEST-R13 roadside representation; road-node position follows source",
            "source_refs": ["K1", "K2", "R11-FACILITIES"],
        }
        if kind in ("hospital", "prison"):
            exit_point = (1, 8) if kind == "hospital" else (0, -1)
            lot["exit_road"] = int(by_coord[exit_point])
            lot["exit_previous"] = int(by_coord[point])
            lot["exit_profile"] = "TEST-R13: release onto adjacent cash tile facing away from terminal; original release tile U"
        lots.append(lot)

    source_dictionary = dict(trace["sources"])
    source_dictionary["R11-FACILITIES"] = {"local_document": "docs/research/r11-facility-exits.md", "scope": "facility identity candidates; footprint size and release point remain test profile"}
    return {
        "schema_version": 1, "id": "knight_manor", "name": "骑士庄园",
        "description": "102道路、58小地产、4共享双入口大地产；测试价格/租金/街道分组/出生与释放出口，新闻及小游戏待还原。",
        "playable": True, "source_status": "B-traced-geometry_TEST-R13-economy-frontage-and-facility-rules",
        "size": list(SIZE), "start_road": -1, "start_bonus": 0,
        "spawn_roads": [int(by_coord[p]) for p in [(0, 0), (12, -2), (20, 7), (11, 17)]],
        "roads": roads, "lots": lots,
        "trace_source": "res://data/maps/knight_manor.trace.json", "trace_sha256": trace_sha,
        "coordinate_profile": {"scale": SCALE, "offset": list(OFFSET), "road_nodes_added": 0, "footprints": "test drawing rectangles; observed original side, integer side-adjacent frontage"},
        "test_profile": {"id": "TEST-R13", "small_price": 2400, "large_price": 12000, "small_base_rent": 360, "large_base_rent": 1800,
                         "street_groups": "19 contiguous visible small-lot runs; original chain grouping U",
                         "large_multi_frontage": "two road nodes share one lot owner/level/building and both trigger stop, per user direction; original equivalence U",
                         "spawns": "four fixed test positions, not verified original spawn rules",
                         "facility_release": "fixed neighboring road facing outward; original release tile U",
                         "cash_trigger": "TEST-R13: settle printed amount only on stop, no pass reward or inflation multiplication; source trigger rule U",
                         "unimplemented": ["original news catalog", "original minigames", "yellow glyph function", "original directional choice rules"]},
        "sources": source_dictionary,
    }


def validate(data, trace):
    roads, lots = data["roads"], data["lots"]
    by_id = {r["id"]: r for r in roads}
    assert len(by_id) == len(roads) == len(trace["nodes"]) == 102
    assert [r["id"] for r in roads] == list(map(str, range(len(roads))))
    assert len({tuple(r["cell"]) for r in roads}) == len(roads)
    trace_to_id = {r["trace_id"]: r["id"] for r in roads}
    expected = {tuple(sorted((trace_to_id[e["from"]], trace_to_id[e["to"]]))) for e in trace["edges"]}
    actual = set()
    road_corridor = set()
    for road in roads:
        p = road["cell"]
        assert 0 <= p[0] < SIZE[0] and 0 <= p[1] < SIZE[1]
        assert len(road["exits"]) == len(set(road["exits"]))
        for target in road["exits"]:
            assert target in by_id and road["id"] in by_id[target]["exits"]
            actual.add(tuple(sorted((road["id"], target))))
            q = by_id[target]["cell"]
            assert (p[0] == q[0]) != (p[1] == q[1])
            assert abs(p[0] - q[0]) + abs(p[1] - q[1]) == SCALE
            dx, dy = (q[0] > p[0]) - (q[0] < p[0]), (q[1] > p[1]) - (q[1] < p[1])
            for i in range(SCALE + 1):
                road_corridor.add((p[0] + dx * i, p[1] + dy * i))
        assert all(ref in data["sources"] for ref in road["source_refs"])
    assert actual == expected and len(actual) == 104
    seen, queue = set(), deque(["0"])
    while queue:
        road_id = queue.popleft()
        if road_id in seen:
            continue
        seen.add(road_id)
        queue.extend(by_id[road_id]["exits"])
    assert seen == set(by_id)
    assert Counter(lot["kind"] for lot in lots) == {"small": 58, "large": 4, "facility": 7}
    assert len({lot["id"] for lot in lots}) == 69
    for i, lot in enumerate(lots):
        rect = lot["footprint"]
        assert all(type(v) is int for v in rect) and rect[2] > 0 and rect[3] > 0
        assert rect[0] >= 0 and rect[1] >= 0 and rect[0] + rect[2] <= SIZE[0] and rect[1] + rect[3] <= SIZE[1]
        assert len(lot["frontage_nodes"]) == (2 if lot["kind"] == "large" else 1)
        for road_id in lot["frontage_nodes"]:
            assert adjacent(by_id[road_id]["cell"], rect), (lot["id"], "frontage", road_id)
        assert not any(contains(rect, point) for point in road_corridor), (lot["id"], "crosses road node/edge corridor")
        for other in lots[:i]:
            assert not overlaps(rect, other["footprint"]), (lot["id"], other["id"], "overlap")
        if "exit_road" in lot:
            assert str(lot["exit_previous"]) in by_id[str(lot["exit_road"])]["exits"]
        assert all(ref in data["sources"] for ref in lot["source_refs"])
    for spawn in data["spawn_roads"]:
        assert str(spawn) in by_id
    for source in data["sources"].values():
        if "local_document" in source:
            assert (ROOT / source["local_document"]).is_file()
    assert data["start_road"] == -1 and data["start_bonus"] == 0
    assert not any(r["kind"] == "start" for r in roads)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check geometry and exact checked-in bytes without writing")
    args = parser.parse_args()
    raw = TRACE.read_bytes()
    trace = json.loads(raw)
    data = build(trace, hashlib.sha256(raw).hexdigest())
    validate(data, trace)
    encoded = (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_bytes() != encoded:
            raise SystemExit("FAIL: generated output differs; run python tools/build_knight_map.py")
    else:
        OUTPUT.write_bytes(encoded)
    print("PASS: 102 roads / 104 edges / 58 small + 4 large + 7 facilities; no footprint or road-corridor overlaps; all frontages edge-adjacent.")
    print("Byte-for-byte reproducibility PASS." if args.check else "Wrote data/maps/knight_manor.json")


if __name__ == "__main__":
    main()
