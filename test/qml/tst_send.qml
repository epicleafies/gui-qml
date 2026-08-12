// Copyright (c) 2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQuick 2.15
import QtQuick.Window 2.15
import QtTest 1.2
import org.bitcoincore.qt 1.0
import "../../qml/pages/wallet"

TestCase {
    name: "Send"
    when: windowShown
    width: 900
    height: 700

    Window {
        id: testWindow
        width: 900
        height: 700
        visible: true
    }

    Component {
        id: sendComponent

        Send {}
    }

    SignalSpy {
        id: transactionPreparedSpy
    }

    function init() {
        testWalletModel.customFeeEnabled = false
        testWalletModel.customFeeRate = ""
        testWalletModel.targetBlocks = 2
        testWalletModel.prepareTransactionResult = true
        testWalletModel.sendAmountExhaustsBalance = false
        testWalletModel.currentTransactionCanSend = true
        testWalletModel.currentTransactionCanBroadcast = false
        testWalletModel.currentTransactionReviewMessage = ""
        testSendRecipient.address.setAddress("bcrt1qsendtoaddress")
        testSendRecipient.amount.display = "0.00000000"
        testSendRecipient.label = ""
        testSendRecipient.subtractFeeFromAmount = false
        testSendRecipient.isValid = true
        testRecipientsModel.allValid = true
        testRecipientsModel.validationError = ""
        testRecipientsModel.clearToFront()
        testRecipientsModel.totalAmountSatoshi = 0
        optionsModel.displayUnit = BitcoinAmount.BTC
        testCoinsListModel.reset()
    }

    function test_review_only_psbt_closes_and_discards_on_wallet_change() {
        const page = createTemporaryObject(sendComponent, testWindow.contentItem)
        verify(page !== null)
        page.width = testWindow.width
        page.height = testWindow.height
        page.visible = true

        const popup = findChild(page, "reviewOnlyPsbtPopup")
        verify(popup !== null)

        testWalletModel.currentTransactionCanSend = false
        testWalletModel.currentTransactionReviewMessage = "This wallet cannot sign."
        const discardCallsBefore = testWalletModel.discardCurrentTransactionCalls

        popup.reviewWallet = testWalletModel
        popup.open()
        tryCompare(popup, "opened", true)

        walletController.setSelectedWallet("review-only-wallet-change")

        tryCompare(popup, "opened", false)
        tryCompare(testWalletModel, "discardCurrentTransactionCalls", discardCallsBefore + 1)
    }

    function test_successful_psbt_broadcast_shows_confirmation() {
        const page = createTemporaryObject(sendComponent, testWindow.contentItem)
        verify(page !== null)
        page.width = testWindow.width
        page.height = testWindow.height
        page.visible = true

        const reviewPopup = findChild(page, "reviewOnlyPsbtPopup")
        const successPopup = findChild(page, "psbtBroadcastSuccessPopup")
        verify(reviewPopup !== null)
        verify(successPopup !== null)

        testWalletModel.currentTransactionCanSend = false
        testWalletModel.currentTransactionCanBroadcast = true
        reviewPopup.reviewWallet = testWalletModel
        reviewPopup.open()
        tryCompare(reviewPopup, "opened", true)

        const broadcastButton = findChild(reviewPopup, "sendReviewBroadcastButton")
        verify(broadcastButton !== null)
        tryCompare(broadcastButton, "visible", true)
        const broadcastCallsBefore = testWalletModel.broadcastCurrentTransactionCalls
        const discardCallsBefore = testWalletModel.discardCurrentTransactionCalls

        broadcastButton.clicked()

        tryCompare(reviewPopup, "opened", false)
        tryCompare(testWalletModel, "broadcastCurrentTransactionCalls", broadcastCallsBefore + 1)
        tryCompare(testWalletModel, "discardCurrentTransactionCalls", discardCallsBefore + 1)
        tryCompare(successPopup, "opened", true)
        successPopup.close()
    }

    function test_send_has_stable_selectors() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        compare(page.objectName, "sendPage")
        verify(findChild(page, "sendAddressInput") !== null)
        verify(findChild(page, "sendAmountInput") !== null)
        verify(findChild(page, "sendNoteInput") !== null)
        verify(findChild(page, "feeSelectionEstimateLabel") !== null)
        verify(findChild(page, "feeSelectionCustomRateInput") !== null)
        verify(findChild(page, "feeSelectionCustomEstimateLabel") !== null)
        verify(findChild(page, "feeSelectionIncludeFeeToggle") !== null)
        verify(findChild(page, "sendFeeIncludedNote") !== null)
        verify(findChild(page, "sendFeeIncludedNoteText") !== null)
        verify(findChild(page, "sendPrepareTransactionError") !== null)
        verify(findChild(page, "sendPrepareTransactionErrorText") !== null)
        verify(findChild(page, "sendTransactionSectionHeader") !== null)
        verify(findChild(page, "sendTotalAmountRow") !== null)
        verify(findChild(page, "sendTotalAmountValue") !== null)
        verify(findChild(page, "sendReviewButton") !== null)
    }

    function test_send_multiple_recipient_layout_and_total_follow_state() {
        const page = createTemporaryObject(sendComponent, testWindow.contentItem)
        verify(page !== null)
        page.width = testWindow.width
        page.height = testWindow.height
        page.visible = true

        const optionsPopup = findChild(page, "sendOptionsPopup")
        const recipientsRow = findChild(page, "sendMultipleRecipientsRow")
        const transactionHeader = findChild(page, "sendTransactionSectionHeader")
        const totalRow = findChild(page, "sendTotalAmountRow")
        const totalValue = findChild(page, "sendTotalAmountValue")
        const addButton = findChild(page, "sendRecipientAddButton")
        const removeButton = findChild(page, "sendRecipientRemoveButton")
        const multipleRecipientsToggle = findChild(page, "sendOptionsMultipleRecipientsToggle")
        verify(optionsPopup !== null)
        verify(recipientsRow !== null)
        verify(transactionHeader !== null)
        verify(totalRow !== null)
        verify(totalValue !== null)
        verify(addButton !== null)
        verify(removeButton !== null)
        verify(multipleRecipientsToggle !== null)

        try {
            optionsPopup.multipleRecipientsEnabled = false
            tryCompare(testRecipientsModel, "count", 1)
            compare(recipientsRow.visible, false)
            compare(transactionHeader.visible, false)
            compare(totalRow.visible, false)

            optionsPopup.open()
            tryCompare(optionsPopup, "opened", true)
            mouseClick(
                multipleRecipientsToggle,
                multipleRecipientsToggle.width / 2,
                multipleRecipientsToggle.height / 2)
            compare(optionsPopup.multipleRecipientsEnabled, true)
            tryCompare(recipientsRow, "visible", true)
            tryCompare(transactionHeader, "visible", true)
            tryCompare(totalRow, "visible", true)
            optionsPopup.close()
            tryCompare(optionsPopup, "opened", false)

            compare(testRecipientsModel.count, 2)
            verify(removeButton.enabled)

            addButton.clicked()
            compare(testRecipientsModel.count, 3)
            verify(removeButton.enabled)

            testRecipientsModel.totalAmountSatoshi = 123456789
            tryCompare(totalValue, "text", "1.23456789 BTC")

            optionsModel.displayUnit = BitcoinAmount.SAT
            tryCompare(totalValue, "text", "123456789 sats")

            removeButton.clicked()
            compare(testRecipientsModel.count, 2)
            removeButton.clicked()
            compare(testRecipientsModel.count, 1)
            compare(removeButton.enabled, false)
        } finally {
            optionsPopup.multipleRecipientsEnabled = false
        }
    }

    function test_amount_input_rules_follow_display_unit() {
        const page = createTemporaryObject(sendComponent, testWindow.contentItem)
        verify(page !== null)

        const amountInput = findChild(page, "sendAmountInput")
        verify(amountInput !== null)

        // BitcoinAmount.mBTC / BitcoinAmount.uBTC are not resolvable from QML
        // (lowercase-initial enum values), so use the display unit integers:
        // 0 = BTC, 1 = mBTC, 2 = uBTC (bits), 3 = SAT.
        optionsModel.displayUnit = 1
        tryCompare(amountInput, "placeholderText", "0.00000")
        compare(amountInput.maximumLength, 17)

        optionsModel.displayUnit = 2
        tryCompare(amountInput, "placeholderText", "0.00")
        compare(amountInput.maximumLength, 17)

        optionsModel.displayUnit = 3
        tryCompare(amountInput, "placeholderText", "0")
        compare(amountInput.maximumLength, 16)

        optionsModel.displayUnit = 0
        tryCompare(amountInput, "placeholderText", "0.00000000")
        compare(amountInput.maximumLength, 17)
    }

    function test_amount_unit_toggle_is_local_to_the_field() {
        const page = createTemporaryObject(sendComponent, testWindow.contentItem)
        verify(page !== null)

        const unitToggle = findChild(page, "sendAmountUnitToggle")
        const unitLabel = findChild(page, "sendAmountUnitLabel")
        verify(unitToggle !== null)
        verify(unitLabel !== null)

        try {
            // The toggle cycles only this field's unit; the persisted display
            // unit must not change. With BTC as the default it is a two-way
            // flip between BTC and sat.
            compare(unitLabel.text, "BTC")
            unitToggle.click()
            tryCompare(unitLabel, "text", "sats")
            compare(optionsModel.displayUnit, 0)
            unitToggle.click()
            tryCompare(unitLabel, "text", "BTC")

            // With bits as the default (display unit integer 2), the cycle
            // includes bits: BTC -> bits -> sat -> BTC.
            optionsModel.defaultDisplayUnit = 2
            tryCompare(unitLabel, "text", "bits")
            unitToggle.click()
            tryCompare(unitLabel, "text", "sats")
            unitToggle.click()
            tryCompare(unitLabel, "text", "BTC")
            unitToggle.click()
            tryCompare(unitLabel, "text", "bits")
        } finally {
            optionsModel.defaultDisplayUnit = 0
        }
    }

    function test_send_continue_button_tracks_recipient_validity() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const continueButton = findChild(page, "sendReviewButton")
        verify(continueButton !== null)

        testRecipientsModel.allValid = false
        tryCompare(continueButton, "enabled", false)

        testRecipientsModel.allValid = true
        tryCompare(continueButton, "enabled", true)
    }

    function test_send_continue_button_requires_fee_buffer() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const continueButton = findChild(page, "sendReviewButton")
        const prepareError = findChild(page, "sendPrepareTransactionError")
        const prepareErrorText = findChild(page, "sendPrepareTransactionErrorText")
        verify(continueButton !== null)
        verify(prepareError !== null)
        verify(prepareErrorText !== null)

        testWalletModel.sendAmountExhaustsBalance = true

        tryCompare(continueButton, "enabled", false)
        tryCompare(page, "formErrorText", "Amount plus fee exceeds available balance")
        compare(prepareErrorText.text, "Amount plus fee exceeds available balance")

        testWalletModel.sendAmountExhaustsBalance = false

        tryCompare(continueButton, "enabled", true)
        tryCompare(page, "formErrorText", "")
        compare(prepareErrorText.text, "")

        testCoinsListModel.toggleCoinSelection(0)
        testWalletModel.sendAmountExhaustsBalance = true

        tryCompare(continueButton, "enabled", false)
        tryCompare(page, "formErrorText", "Selected inputs do not cover the amount plus fee")
        compare(prepareErrorText.text, "Selected inputs do not cover the amount plus fee")
    }

    function test_send_shows_recipient_validation_error() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const continueButton = findChild(page, "sendReviewButton")
        const prepareError = findChild(page, "sendPrepareTransactionError")
        const prepareErrorText = findChild(page, "sendPrepareTransactionErrorText")
        verify(continueButton !== null)
        verify(prepareError !== null)
        verify(prepareErrorText !== null)

        testRecipientsModel.allValid = false
        testRecipientsModel.validationError = "Complete every recipient before continuing."

        tryCompare(continueButton, "enabled", false)
        tryCompare(page, "recipientValidationError", "Complete every recipient before continuing.")
        tryCompare(prepareErrorText, "text", "Complete every recipient before continuing.")
    }

    function test_send_prepare_transaction_success_and_failure_paths() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const continueButton = findChild(page, "sendReviewButton")
        const prepareError = findChild(page, "sendPrepareTransactionError")
        const prepareErrorText = findChild(page, "sendPrepareTransactionErrorText")
        verify(continueButton !== null)
        verify(prepareError !== null)
        verify(prepareErrorText !== null)

        testSendRecipient.isValid = true
        transactionPreparedSpy.target = page
        transactionPreparedSpy.signalName = "transactionPrepared"
        transactionPreparedSpy.clear()

        const callsBefore = testWalletModel.prepareTransactionCalls
        compare(page.prepareTransactionErrorText, "")
        compare(prepareErrorText.text, "")

        testWalletModel.prepareTransactionResult = false
        continueButton.clicked()
        compare(testWalletModel.prepareTransactionCalls, callsBefore + 1)
        compare(transactionPreparedSpy.count, 0)
        compare(page.prepareTransactionErrorText, "Amount plus fee exceeds available balance")
        compare(prepareErrorText.text, "Amount plus fee exceeds available balance")

        page.prepareTransactionErrorText = ""
        testCoinsListModel.toggleCoinSelection(0)
        continueButton.clicked()
        compare(testWalletModel.prepareTransactionCalls, callsBefore + 2)
        compare(transactionPreparedSpy.count, 0)
        compare(page.prepareTransactionErrorText, "Selected inputs do not cover the amount plus fee")
        compare(prepareErrorText.text, "Selected inputs do not cover the amount plus fee")

        testWalletModel.prepareTransactionResult = true
        continueButton.clicked()
        compare(testWalletModel.prepareTransactionCalls, callsBefore + 3)
        compare(transactionPreparedSpy.count, 1)
        compare(transactionPreparedSpy.signalArguments[0][0], false)
        compare(page.prepareTransactionErrorText, "")
        compare(prepareErrorText.text, "")
    }

    function test_send_fee_selection_updates_wallet_target_blocks() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        testWalletModel.targetBlocks = 2
        const popup = findChild(page, "feeSelectionPopup")
        const list = findChild(page, "feeSelectionList")
        verify(popup !== null)
        verify(list !== null)

        popup.open()
        tryVerify(function() {
            return list.itemAtIndex(0) !== null
        })

        const highFeeOption = list.itemAtIndex(0)
        verify(highFeeOption !== null)
        highFeeOption.clicked()

        compare(testWalletModel.targetBlocks, 1)
    }

    function test_send_amount_changes_schedule_live_fee_estimation() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const amountInput = findChild(page, "sendAmountInput")
        verify(amountInput !== null)

        amountInput.text = ""
        amountInput.forceActiveFocus()
        verify(amountInput.activeFocus)
        const callsBefore = testWalletModel.scheduleFeeEstimatesCalls
        keyClick("1")

        tryCompare(testWalletModel, "scheduleFeeEstimatesCalls", callsBefore + 1)
        compare(amountInput.text, "1")
        compare(testSendRecipient.amount.display, "1.00000000")
    }

    function test_send_amount_allows_editing_whole_part_before_decimal() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const amountInput = findChild(page, "sendAmountInput")
        verify(amountInput !== null)

        amountInput.text = "0.00000000"
        amountInput.cursorPosition = 1
        amountInput.forceActiveFocus()
        verify(amountInput.activeFocus)
        keyClick("1")

        compare(amountInput.text, "01.00000000")
        compare(testSendRecipient.amount.display, "1.00000000")

        amountInput.focus = false
        wait(0)
        compare(amountInput.activeFocus, false)
        compare(amountInput.text, "1.00000000")
    }

    function test_send_amount_rejects_extra_decimal_digits_while_editing() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const amountInput = findChild(page, "sendAmountInput")
        verify(amountInput !== null)

        testSendRecipient.amount.display = "0.12345678"
        tryCompare(amountInput, "text", "0.12345678")
        amountInput.cursorPosition = amountInput.text.length
        amountInput.forceActiveFocus()
        verify(amountInput.activeFocus)
        keyClick("9")

        compare(amountInput.text, "0.12345678")
        compare(testSendRecipient.amount.display, "0.12345678")

        amountInput.focus = false
        wait(0)
        compare(amountInput.activeFocus, false)
        compare(amountInput.text, "0.12345678")
    }

    function test_send_amount_rejects_extra_decimal_points_while_editing() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const amountInput = findChild(page, "sendAmountInput")
        verify(amountInput !== null)

        testSendRecipient.amount.display = "1.20000000"
        amountInput.text = "1.2"
        amountInput.cursorPosition = amountInput.text.length
        amountInput.forceActiveFocus()
        verify(amountInput.activeFocus)
        keyClick(".")

        compare(amountInput.text, "1.2")
        compare(testSendRecipient.amount.display, "1.20000000")
    }

    function test_send_shows_selected_estimated_fee() {
        testWalletModel.targetBlocks = 2

        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const estimateLabel = findChild(page, "feeSelectionEstimateLabel")
        verify(estimateLabel !== null)
        compare(estimateLabel.text, "0.00000500 ₿")
    }

    function test_send_custom_fee_selection_updates_wallet_mode() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const popup = findChild(page, "feeSelectionPopup")
        const list = findChild(page, "feeSelectionList")
        const customInput = findChild(page, "feeSelectionCustomRateInput")
        verify(popup !== null)
        verify(list !== null)
        verify(customInput !== null)

        popup.open()
        tryVerify(function() {
            return list.itemAtIndex(3) !== null
        })
        list.itemAtIndex(3).clicked()

        compare(testWalletModel.customFeeEnabled, true)

        popup.open()
        tryVerify(function() {
            return list.itemAtIndex(0) !== null
        })
        list.itemAtIndex(0).clicked()

        compare(testWalletModel.customFeeEnabled, false)
        compare(testWalletModel.targetBlocks, 1)
    }

    function test_send_continue_button_requires_valid_custom_fee() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const popup = findChild(page, "feeSelectionPopup")
        const list = findChild(page, "feeSelectionList")
        const continueButton = findChild(page, "sendReviewButton")
        const customInput = findChild(page, "feeSelectionCustomRateInput")
        verify(popup !== null)
        verify(list !== null)
        verify(continueButton !== null)
        verify(customInput !== null)

        testSendRecipient.isValid = true

        popup.open()
        tryVerify(function() {
            return list.itemAtIndex(3) !== null
        })
        list.itemAtIndex(3).clicked()

        compare(continueButton.enabled, false)

        customInput.text = "2"
        tryCompare(continueButton, "enabled", true)
    }

    function test_send_include_fee_note_tracks_recipient_state() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const includedFeeNote = findChild(page, "sendFeeIncludedNote")
        const includedFeeNoteText = findChild(page, "sendFeeIncludedNoteText")
        verify(includedFeeNote !== null)
        verify(includedFeeNoteText !== null)

        compare(includedFeeNote.visible, false)
        compare(includedFeeNoteText.text, "Fee is included in the amount")
    }

    function test_send_include_fee_toggle_updates_recipient_and_schedules_fee_estimate() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const popup = findChild(page, "feeSelectionPopup")
        const toggle = findChild(page, "feeSelectionIncludeFeeToggle")
        const note = findChild(page, "sendFeeIncludedNote")
        verify(popup !== null)
        verify(toggle !== null)
        verify(note !== null)

        const callsBefore = testWalletModel.scheduleFeeEstimatesCalls

        popup.open()
        tryCompare(popup, "opened", true)

        mouseClick(toggle, toggle.width / 2, toggle.height / 2)

        compare(testSendRecipient.subtractFeeFromAmount, true)
        tryCompare(testWalletModel, "scheduleFeeEstimatesCalls", callsBefore + 1)
        tryCompare(popup, "visible", false)
    }

    function test_send_uri_import_schedules_fee_estimate() {
        const page = createTemporaryObject(sendComponent, this)
        verify(page !== null)

        const sendPage = findChild(page, "walletSendPage")
        verify(sendPage !== null)

        const callsBefore = testWalletModel.scheduleFeeEstimatesCalls
        sendPage.applyPaymentRequestFromText(
            "bitcoin:bcrt1qdavt4j2sd7dlhqsavtnfxvzppw6k7qy97tmnu9?amount=0.02000000&label=uri-label",
            "clipboard"
        )

        // The mocked amount input still emits one schedule request when the
        // imported amount updates the bound field. The explicit URI-import
        // refresh added in Send.qml should contribute one more call.
        tryCompare(testWalletModel, "scheduleFeeEstimatesCalls", callsBefore + 2)
        compare(testSendRecipient.address.address, "bcrt1qdavt4j2sd7dlhqsavtnfxvzppw6k7qy97tmnu9")
        compare(testSendRecipient.amount.display, "0.02000000")
        compare(testSendRecipient.label, "uri-label")
        compare(sendPage.paymentRequestStatus, "Payment request imported from clipboard")
        compare(sendPage.paymentRequestIsError, false)
    }
}
