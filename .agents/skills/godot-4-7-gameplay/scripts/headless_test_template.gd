# Reusable Headless Test Template for Godot 4.7
# Run via: godot --headless --script res://.agents/skills/godot-4-7-gameplay/scripts/headless_test_template.gd
extends SceneTree

var _total_assertions: int = 0
var _failed_assertions: int = 0

func _init() -> void:
    print("==================================================")
    print("  Godot 4.7 Headless Verification Harness")
    print("==================================================")

    _run_suite()

    print("--------------------------------------------------")
    print("Total Checks: %d | Failures: %d" % [_total_assertions, _failed_assertions])

    if _failed_assertions > 0:
        print("[RESULT] Suite FAILED.")
        quit(1)
    else:
        print("[RESULT] Suite PASSED.")
        quit(0)

func _assert_true(condition: bool, description: String) -> void:
    _total_assertions += 1
    if not condition:
        _failed_assertions += 1
        printerr("  [FAIL] %s" % description)
    else:
        print("  [PASS] %s" % description)

func _assert_eq(actual: Variant, expected: Variant, description: String) -> void:
    _total_assertions += 1
    if actual != expected:
        _failed_assertions += 1
        printerr("  [FAIL] %s (Expected: %s, Got: %s)" % [description, str(expected), str(actual)])
    else:
        print("  [PASS] %s" % description)

func _run_suite() -> void:
    # 1. Coordinate & Vector Math Invariants
    var cell_a := Vector2i(2, 3)
    var cell_b := Vector2i(0, -1)
    _assert_eq(cell_a + cell_b, Vector2i(2, 2), "Vector2i coordinate addition")

    # 2. StringName comparisons (zero allocation)
    var act: StringName = &"move_up"
    _assert_true(act == &"move_up", "StringName equality check")

    # 3. Custom tests hook (extend here with project-specific models)
    _assert_true(true, "Core headless harness functional")
