#!/usr/bin/env python3
# Copyright (c) 2026 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
"""End-to-end tests for the Display settings page.

Tests language selection, display unit switching (BTC / mBTC / bits / SAT),
and the "Ask before opening links" toggle.

These tests run post-onboarding and do not require a peer connection, but
they do require the node to start up, so generous wait timeouts are used.

This test requires:
  - bitcoin-core-app built with -DENABLE_TEST_AUTOMATION=ON
"""

import shutil
import sys
import time

from qml_test_harness import (
    GUI_STARTUP_TIMEOUT,
    QmlTestHarness,
    complete_onboarding,
    dump_qml_tree,
    parse_args,
)
from qml_driver import QmlDriverError

# The node must start up before post-onboarding pages are interactive.
# Use a generous timeout for waits that follow onboarding completion.
POST_ONBOARDING_TIMEOUT_MS = 30000
DISPLAY_SETTING_ROWS = (
    "gotoTheme",
    "gotoDisplayUnit",
    "gotoLanguage",
    "gotoThirdPartyTransactionUrls",
    "gotoMoneyFont",
)


# ── Navigation helpers ────────────────────────────────────────────────────────

def navigate_to_display_settings(gui):
    """From the NodeRunner main screen, navigate to the Display settings page."""
    gui.click("nodeSettingsButton")
    # Display is a sidebar section (settings_display) in the desktop layout.
    gui.wait_for_property("settings_display", "visible", True, timeout_ms=5000)
    gui.click("settings_display")
    # SettingsDisplay is identified by the presence of gotoDisplayUnit.
    gui.wait_for_page("gotoDisplayUnit", timeout_ms=5000)
    print("  Navigated to Display settings page")


def assert_display_rows_have_no_descriptions(gui):
    """The top-level Display page follows the single-line row design."""
    for row in DISPLAY_SETTING_ROWS:
        description = gui.get_property(row, "description")
        assert description == "", f"{row} should not show subtext, got: {description!r}"


def reset_display_unit_to_btc(gui):
    """Reset the persisted display unit to BTC.

    Precondition: caller is on the SettingsDisplay page with gotoDisplayUnit
    visible. Callers should wrap invocations in `try/except QmlDriverError:
    pass` for best-effort teardown that does not mask the original test failure.
    """
    gui.click("gotoDisplayUnit")
    gui.wait_for_page("settingsDisplayUnitPage", timeout_ms=5000)
    gui.click("displayUnitBTC")
    gui.click("settingsDisplayUnitBack")
    gui.wait_for_page("gotoDisplayUnit", timeout_ms=5000)


def reset_language_to_system_default(gui):
    """Reset the persisted language to the System default (empty tag).

    Precondition: caller is on the SettingsDisplay page with gotoLanguage
    visible. The helper navigates into SettingsLanguage, picks the empty-tag
    delegate, and waits to return to SettingsDisplay. Callers should wrap
    invocations in `try/except QmlDriverError: pass` for best-effort teardown
    that does not mask the original test failure.
    """
    gui.click("gotoLanguage")
    gui.wait_for_page("settingsLanguagePage", timeout_ms=5000)
    gui.wait_for_page("language_", timeout_ms=3000)  # wait for delegate to render
    gui.click("language_")  # objectName: "language_" + "" = "language_"
    gui.wait_for_page("gotoLanguage", timeout_ms=5000)


# ── Individual test cases ─────────────────────────────────────────────────────

def test_display_unit_selection(gui):
    """Select SAT on the Display unit page and verify it is reflected."""
    print("\n── test_display_unit_selection ───────────────────────────────")

    try:
        gui.click("gotoDisplayUnit")
        gui.wait_for_page("settingsDisplayUnitPage", timeout_ms=5000)
        print("  Navigated to SettingsDisplayUnit page")

        # If SAT is selected (state persists across runs), switch to BTC first.
        # We must navigate to a fresh page after the switch because clicking a
        # checkable OptionButton breaks its declarative `checked:` binding.
        if gui.get_property("displayUnitSAT", "checked"):
            gui.click("displayUnitBTC")
            gui.click("settingsDisplayUnitBack")
            gui.wait_for_page("gotoDisplayUnit", timeout_ms=5000)
            gui.click("gotoDisplayUnit")
            gui.wait_for_page("settingsDisplayUnitPage", timeout_ms=5000)
            print("  Switched to BTC starting state")

        btc_checked = gui.get_property("displayUnitBTC", "checked")
        sat_checked = gui.get_property("displayUnitSAT", "checked")
        assert btc_checked, (
            f"BTC should be checked at test start, got btc={btc_checked} sat={sat_checked}"
        )
        assert not sat_checked, (
            f"SAT should not be checked at test start, got sat={sat_checked}"
        )
        print(f"  Starting state: BTC={btc_checked}, SAT={sat_checked}  PASSED")

        # Select SAT.
        gui.click("displayUnitSAT")
        sat_after = gui.get_property("displayUnitSAT", "checked")
        btc_after = gui.get_property("displayUnitBTC", "checked")
        assert sat_after, f"SAT should be checked after clicking, got sat={sat_after}"
        assert not btc_after, f"BTC should be unchecked after selecting SAT, got btc={btc_after}"
        print(f"  After SAT selection: SAT={sat_after}, BTC={btc_after}  PASSED")

        # Go back and reset to BTC for future runs.
        gui.click("settingsDisplayUnitBack")
        gui.wait_for_page("gotoDisplayUnit", timeout_ms=5000)

        gui.click("gotoDisplayUnit")
        gui.wait_for_page("settingsDisplayUnitPage", timeout_ms=5000)
        gui.click("displayUnitBTC")
        gui.click("settingsDisplayUnitBack")
        gui.wait_for_page("gotoDisplayUnit", timeout_ms=5000)
        print("  Reset display unit to BTC  PASSED")
    finally:
        try:
            reset_display_unit_to_btc(gui)
        except QmlDriverError:
            pass


def test_display_unit_mbtc_and_bits_selection(gui):
    """Select mBTC and bits on the Display unit page and verify each sticks."""
    print("\n── test_display_unit_mbtc_and_bits_selection ─────────────────")

    try:
        gui.click("gotoDisplayUnit")
        gui.wait_for_page("settingsDisplayUnitPage", timeout_ms=5000)

        # Select mBTC.
        gui.click("displayUnitMBTC")
        mbtc_checked = gui.get_property("displayUnitMBTC", "checked")
        btc_checked = gui.get_property("displayUnitBTC", "checked")
        assert mbtc_checked, f"mBTC should be checked after clicking, got {mbtc_checked}"
        assert not btc_checked, f"BTC should be unchecked after selecting mBTC, got {btc_checked}"
        print(f"  After mBTC selection: mBTC={mbtc_checked}, BTC={btc_checked}  PASSED")

        # Re-navigate before the next selection because clicking a checkable
        # OptionButton breaks its declarative `checked:` binding.
        gui.click("settingsDisplayUnitBack")
        gui.wait_for_page("gotoDisplayUnit", timeout_ms=5000)
        gui.click("gotoDisplayUnit")
        gui.wait_for_page("settingsDisplayUnitPage", timeout_ms=5000)
        assert gui.get_property("displayUnitMBTC", "checked"), (
            "mBTC selection should persist across page navigation"
        )

        # Select bits (uBTC).
        gui.click("displayUnitUBTC")
        ubtc_checked = gui.get_property("displayUnitUBTC", "checked")
        mbtc_after = gui.get_property("displayUnitMBTC", "checked")
        assert ubtc_checked, f"bits should be checked after clicking, got {ubtc_checked}"
        assert not mbtc_after, f"mBTC should be unchecked after selecting bits, got {mbtc_after}"
        print(f"  After bits selection: bits={ubtc_checked}, mBTC={mbtc_after}  PASSED")

        gui.click("settingsDisplayUnitBack")
        gui.wait_for_page("gotoDisplayUnit", timeout_ms=5000)
    finally:
        try:
            reset_display_unit_to_btc(gui)
        except QmlDriverError:
            pass


def test_language_selection(gui):
    """Select Spanish and verify translated headers update."""
    print("\n── test_language_selection ───────────────────────────────────")

    try:
        gui.click("gotoLanguage")
        gui.wait_for_page("settingsLanguagePage", timeout_ms=5000)
        print("  Navigated to SettingsLanguage page")

        # Filter the list to Spanish so the delegate is rendered by the ListView.
        gui.set_text("languageSearch", "español")
        gui.wait_for_page("language_es", timeout_ms=3000)
        gui.click("language_es")
        # Selecting a language navigates back to SettingsDisplay automatically.
        gui.wait_for_page("gotoLanguage", timeout_ms=5000)
        print("  Selected Spanish (es) and returned to Display settings")

        assert_display_rows_have_no_descriptions(gui)

        # Verify translation propagated to other row headers on this page.
        lang_header = gui.get_property("gotoLanguage", "header")
        assert lang_header == "Idioma", (
            f"'Language' row header should be 'Idioma' in Spanish, got: {lang_header!r}"
        )
        print(f"  Language row header translated: {lang_header!r}  PASSED")

        unit_header = gui.get_property("gotoDisplayUnit", "header")
        assert unit_header == "Unidad de visualización", (
            f"'Display unit' row header should be translated in Spanish, got: {unit_header!r}"
        )
        print(f"  Display unit row header translated: {unit_header!r}  PASSED")

        # Reset to System default (empty tag).
        gui.click("gotoLanguage")
        gui.wait_for_page("settingsLanguagePage", timeout_ms=5000)
        gui.wait_for_page("language_", timeout_ms=3000)  # wait for delegate to render
        gui.click("language_")  # objectName: "language_" + "" = "language_"
        gui.wait_for_page("gotoLanguage", timeout_ms=5000)

        assert_display_rows_have_no_descriptions(gui)
        print("  Reset to System default  PASSED")

        # Verify English headers are restored after reset.
        lang_header_reset = gui.get_property("gotoLanguage", "header")
        assert lang_header_reset == "Language", (
            f"'Language' header should be restored to English after reset, got: {lang_header_reset!r}"
        )
        unit_header_reset = gui.get_property("gotoDisplayUnit", "header")
        assert unit_header_reset == "Display unit", (
            f"'Display unit' header should be restored to English after reset, got: {unit_header_reset!r}"
        )
        print(f"  Headers restored to English  PASSED")
    finally:
        # Best-effort: if the test failed mid-flow the persisted language may
        # still be Spanish. Reset to System default so the restart phase starts
        # from a known state within this test's temporary QSettings sandbox.
        try:
            reset_language_to_system_default(gui)
        except QmlDriverError:
            pass


def test_settings_persistence(datadir):
    """Restart the app without -resetguisettings and verify settings persisted.

    Issue #512 requires: change unit/language → restart → verify persisted.
    """
    print("\n── test_settings_persistence ─────────────────────────────────")

    harness2 = QmlTestHarness(
        extra_args=["-disablewallet"],
        reset_settings=False,
        datadir=datadir,
    )
    try:
        harness2.start()
        gui2 = harness2.driver

        try:
            # Runtime restart tests launch as onboarded so they stay focused on
            # display setting persistence, not first-run onboarding.
            gui2.wait_for_page("nodeSettingsButton", timeout_ms=POST_ONBOARDING_TIMEOUT_MS)
            print("  Reached NodeRunner main screen after restart")

            navigate_to_display_settings(gui2)

            # Verify SAT is still selected.
            gui2.click("gotoDisplayUnit")
            gui2.wait_for_page("settingsDisplayUnitPage", timeout_ms=5000)
            sat_persisted = gui2.get_property("displayUnitSAT", "checked")
            assert sat_persisted, (
                f"SAT should still be selected after restart, got checked={sat_persisted}"
            )
            print("  Display unit (SAT) persisted across restart  PASSED")
            gui2.click("settingsDisplayUnitBack")
            gui2.wait_for_page("gotoDisplayUnit", timeout_ms=5000)

            # Verify Spanish is still selected through translated Display rows.
            lang_header = gui2.get_property("gotoLanguage", "header")
            assert lang_header == "Idioma", (
                f"'Language' row header should be Spanish after restart, got: {lang_header!r}"
            )
            unit_header = gui2.get_property("gotoDisplayUnit", "header")
            assert unit_header == "Unidad de visualización", (
                f"'Display unit' row header should be Spanish after restart, got: {unit_header!r}"
            )
            assert_display_rows_have_no_descriptions(gui2)
            print("  Language (Español) persisted across restart  PASSED")
        finally:
            # Best-effort: reset persisted settings to defaults before the
            # harness shuts down. Values are flushed by QSettings on app exit,
            # so this must run before harness2.stop(). Swallow driver errors
            # so a mid-test failure is not masked.
            try:
                reset_display_unit_to_btc(gui2)
            except QmlDriverError:
                pass
            try:
                reset_language_to_system_default(gui2)
            except QmlDriverError:
                pass

    finally:
        harness2.stop()


# ── Main ──────────────────────────────────────────────────────────────────────

def run_tests():
    args = parse_args()
    harness = QmlTestHarness(socket_path=args.socket_path, extra_args=["-disablewallet"])
    try:
        harness.start()
        gui = harness.driver

        # Complete onboarding to reach the main node screen.
        complete_onboarding(gui)

        # Wait for the NodeRunner main screen.
        # Uses a generous timeout because the node starts up after onboarding.
        gui.wait_for_page("nodeSettingsButton", timeout_ms=POST_ONBOARDING_TIMEOUT_MS)
        print("Reached NodeRunner main screen")

        navigate_to_display_settings(gui)
        assert_display_rows_have_no_descriptions(gui)

        test_display_unit_selection(gui)
        test_display_unit_mbtc_and_bits_selection(gui)
        test_language_selection(gui)

        # Set known state for persistence test: SAT + Spanish.
        print("\n── Setting up state for persistence test ─────────────────────")
        gui.click("gotoDisplayUnit")
        gui.wait_for_page("settingsDisplayUnitPage", timeout_ms=5000)
        gui.click("displayUnitSAT")
        gui.click("settingsDisplayUnitBack")
        gui.wait_for_page("gotoDisplayUnit", timeout_ms=5000)
        gui.click("gotoLanguage")
        gui.wait_for_page("settingsLanguagePage", timeout_ms=5000)
        gui.set_text("languageSearch", "español")
        gui.wait_for_page("language_es", timeout_ms=3000)
        gui.click("language_es")
        gui.wait_for_page("gotoLanguage", timeout_ms=5000)
        print("  State set: SAT + Spanish")

        datadir = harness.datadir
        tmpdir = harness.tmpdir

    except Exception as e:
        print(f"\nFAILED: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        if harness.driver:
            dump_qml_tree(harness.driver)
        sys.exit(1)
    finally:
        # Keep the datadir on disk so the second harness can reuse it.
        harness.stop(cleanup=False)

    # Phase 2: restart without -resetguisettings and verify persistence.
    try:
        test_settings_persistence(datadir)
    except Exception as e:
        print(f"\nFAILED: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        if tmpdir:
            shutil.rmtree(tmpdir, ignore_errors=True)

    print("\n" + "=" * 60)
    print("All display settings tests PASSED")
    print("=" * 60)


if __name__ == '__main__':
    run_tests()
