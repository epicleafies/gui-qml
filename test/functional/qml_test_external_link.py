#!/usr/bin/env python3
# Copyright (c) 2026 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
"""End-to-end tests for the ExternalPopup failure/retry/copy flow.

When Qt.openUrlExternally() fails (returns false), the popup should show
a failure banner with copy-to-clipboard and retry options instead of
silently closing.

In the offscreen test environment (QT_QPA_PLATFORM=offscreen),
openUrlExternally() always returns false, which naturally exercises the
failure path.

This test requires:
  - bitcoin-core-app built with -DENABLE_TEST_AUTOMATION=ON
"""

import sys

from qml_test_harness import (
    QmlTestHarness,
    complete_onboarding,
    dump_qml_tree,
    parse_args,
)
POST_ONBOARDING_TIMEOUT_MS = 30000


# ── Navigation helpers ────────────────────────────────────────────────────────

def navigate_to_about(gui):
    """From the NodeRunner main screen, navigate to Settings > About."""
    gui.click("nodeSettingsButton")
    gui.wait_for_page("gotoAboutSetting", timeout_ms=5000)
    gui.click("gotoAboutSetting")
    gui.wait_for_page("websiteLinkSetting", timeout_ms=5000)
    print("  Navigated to About page")


def open_external_popup(gui):
    """Click the Website link to open the ExternalPopup."""
    gui.click("websiteLinkSetting")
    gui.wait_for_page("externalPopup", timeout_ms=5000)
    print("  ExternalPopup opened")


# ── Individual test cases ─────────────────────────────────────────────────────

def test_confirm_cancel(gui):
    """Open the popup and cancel — popup should close without opening URL."""
    print("\n── test_confirm_cancel ──────────────────────────────────────")

    open_external_popup(gui)

    state = gui.get_property("externalPopup", "popupState")
    assert state == "confirm", f"Expected 'confirm' state, got {state!r}"
    print(f"  Initial state: {state!r}  PASSED")

    gui.click("externalPopupCancel")
    gui.wait_for_property("externalPopup", "visible", False)
    print("  Popup closed after Cancel  PASSED")


def test_open_triggers_failure(gui):
    """Click Ok — in offscreen mode this always fails, popup should stay open."""
    print("\n── test_open_triggers_failure ───────────────────────────────")

    open_external_popup(gui)

    gui.click("externalPopupOk")
    gui.wait_for_property("externalPopup", "popupState", "failure")
    print("  State after Ok: failure  PASSED")

    visible = gui.get_property("externalPopup", "visible")
    assert visible, "Popup should remain visible in failure state"
    print("  Popup stays open in failure state  PASSED")

    url_text = gui.get_property("externalPopupUrl", "text")
    assert "bitcoincore.org" in url_text, (
        f"URL text should contain 'bitcoincore.org', got {url_text!r}"
    )
    print(f"  URL displayed: {url_text!r}  PASSED")


def test_failure_copy(gui):
    """In failure state, click the copy icon — should not crash."""
    print("\n── test_failure_copy ────────────────────────────────────────")

    state = gui.get_property("externalPopup", "popupState")
    assert state == "failure", f"Expected to be in failure state, got {state!r}"

    gui.click("externalPopupCopy")
    gui.wait_for_property("externalPopupCopy", "showCheck", True)
    print("  Copy icon toggled to check  PASSED")

    gui.wait_for_property("externalPopupCopy", "showCheck", False, timeout_ms=5000)
    print("  Copy icon reverted after timeout  PASSED")


def test_failure_retry(gui):
    """In failure state, click Try again — should stay in failure (still offscreen)."""
    print("\n── test_failure_retry ───────────────────────────────────────")

    state = gui.get_property("externalPopup", "popupState")
    assert state == "failure", f"Expected to be in failure state, got {state!r}"

    gui.click("externalPopupRetry")
    gui.wait_for_property("externalPopup", "popupState", "failure")
    print("  State after retry: failure (as expected in offscreen)  PASSED")

    visible = gui.get_property("externalPopup", "visible")
    assert visible, "Popup should remain visible after retry"
    print("  Popup stays open after retry  PASSED")


def test_failure_close(gui):
    """In failure state, click Close — popup should dismiss."""
    print("\n── test_failure_close ───────────────────────────────────────")

    state = gui.get_property("externalPopup", "popupState")
    assert state == "failure", f"Expected to be in failure state, got {state!r}"

    gui.click("externalPopupClose")
    gui.wait_for_property("externalPopup", "visible", False)
    print("  Popup closed after Close  PASSED")


# ── Main ──────────────────────────────────────────────────────────────────────

def run_tests():
    args = parse_args()
    harness = QmlTestHarness(socket_path=args.socket_path, extra_args=["-disablewallet"])
    try:
        harness.start()
        gui = harness.driver

        complete_onboarding(gui)

        gui.wait_for_page("nodeSettingsButton", timeout_ms=POST_ONBOARDING_TIMEOUT_MS)
        print("Reached NodeRunner main screen")

        navigate_to_about(gui)

        test_confirm_cancel(gui)
        test_open_triggers_failure(gui)
        test_failure_copy(gui)
        test_failure_retry(gui)
        test_failure_close(gui)

    except Exception as e:
        print(f"\nFAILED: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        if harness.driver:
            dump_qml_tree(harness.driver)
        sys.exit(1)
    finally:
        harness.stop()

    print("\n" + "=" * 60)
    print("All external link tests PASSED")
    print("=" * 60)


if __name__ == '__main__':
    run_tests()
