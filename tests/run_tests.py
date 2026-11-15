#!/usr/bin/env python3
"""
Pixel Pilferer Master Headless Test Runner
Executes domain invariant tests, rule checks, and all 20 level solvability proofs.
Exits with 0 on full success, 1 on any failure.
"""

import sys
import os

# Add tests directory to python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from test_domain_model import run_unit_tests
from test_puzzle_solver import verify_all_levels
from test_vertical_slice import run_vertical_slice_tests
from test_solver_validation import run_solver_validation_tests
from test_adversarial_qa import run_adversarial_suite

def main() -> int:
    print("=======================================================")
    print("         PIXEL PILFERER AUTOMATED TEST SUITE           ")
    print("=======================================================\n")

    # Step 1: Run domain model unit tests
    unit_result = run_unit_tests()
    if unit_result != 0:
        print("\n[ERROR] Domain invariant tests failed!")
        return 1

    print("\n")

    # Step 2: Run vertical slice demo levels verification
    demo_result = run_vertical_slice_tests()
    if demo_result != 0:
        print("\n[ERROR] Vertical slice demo levels verification failed!")
        return 1

    print("\n")

    # Step 3: Run Phase 4 solver, validation, and hint tests
    p4_result = run_solver_validation_tests()
    if p4_result != 0:
        print("\n[ERROR] Phase 4 solver & validation tests failed!")
        return 1

    print("\n")

    # Step 4: Run all 23 level solvability proofs
    levels_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "levels")
    solver_result = verify_all_levels(levels_dir)
    if not solver_result:
        print("\n[ERROR] Level solvability verification failed!")
        return 1

    print("\n")

    # Step 5: Run Phase 8 Adversarial QA & Reliability Suite
    p8_result = run_adversarial_suite()
    if p8_result != 0:
        print("\n[ERROR] Phase 8 Adversarial QA tests failed!")
        return 1

    print("\n=======================================================")
    print(" [ALL TESTS PASSED] Domain, rules, solver, & QA audit OK")
    print("=======================================================")
    return 0

if __name__ == "__main__":
    sys.exit(main())
