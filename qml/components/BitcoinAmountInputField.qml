// Copyright (c) 2025-2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.bitcoincore.qt 1.0

import "../controls"

ColumnLayout {
    id: root

    property var amount
    property string errorText: ""
    property string labelText: qsTr("Amount")
    property string accessibleName: labelText
    property alias inputObjectName: amountInput.objectName
    property alias unitToggleObjectName: unitToggle.objectName
    property alias unitLabelObjectName: unitLabel.objectName
    property alias errorTextObjectName: errorTextLabel.objectName
    property bool enabled: true
    property string placeholderText: root.amount ? root.amount.inputPlaceholder : "0.00000000"

    signal inputTextChanged
    signal textEdited
    signal editingFinished(string value)

    function syncFromAmount(force) {
        amountInput.syncFromAmount(force)
    }

    Layout.fillWidth: true
    spacing: 4

    Item {
        id: inputRow
        Layout.fillWidth: true
        Layout.preferredHeight: 56

        CoreText {
            id: lbl
            width: 128
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            text: root.labelText
            font: Theme.text.body.font
            lineHeight: Theme.text.body.lineHeight
            lineHeightMode: Text.FixedHeight
        }

        TextField {
            id: amountInput
            property bool syncingFromAmount: false

            function amountDisplay() {
                return root.amount ? root.amount.display : ""
            }

            // Keep user draft text while focused, then pull from BitcoinAmount
            // after format() so the field shows the clean canonical display.
            function syncFromAmount(force) {
                if (!force && activeFocus) return
                const display = amountDisplay()
                if (text === display) return
                syncingFromAmount = true
                text = display
                syncingFromAmount = false
            }

            function commitAmountText() {
                if (root.amount && root.amount.display !== text) {
                    root.amount.display = text
                }
            }

            function finishAmountEditing() {
                commitAmountText()
                if (root.amount) {
                    root.amount.format()
                    root.syncFromAmount(true)
                }
                root.editingFinished(text)
            }

            Accessible.name: root.accessibleName
            anchors.left: lbl.right
            anchors.right: unitToggle.left
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 0
            enabled: root.enabled
            font: Theme.text.body.font
            color: Theme.color.neutral9
            placeholderTextColor: enabled ? Theme.color.neutral7 : Theme.color.neutral4
            background: Item {}
            placeholderText: root.placeholderText
            selectByMouse: true

            text: ""
            Component.onCompleted: root.syncFromAmount(true)

            onTextChanged: {
                if (!syncingFromAmount) {
                    root.inputTextChanged()
                }
            }

            onTextEdited: {
                commitAmountText()
                root.textEdited()
            }

            onEditingFinished: finishAmountEditing()

            onActiveFocusChanged: {
                if (!activeFocus) {
                    finishAmountEditing()
                }
            }

            validator: RegularExpressionValidator {
                regularExpression: root.amount ? new RegExp(root.amount.inputPattern) : /^(0|[1-9]\d{0,7})(\.\d{0,8})?$/
            }
            maximumLength: root.amount ? root.amount.maximumInputLength : 17

            Connections {
                target: root
                function onAmountChanged() {
                    root.syncFromAmount(true)
                }
            }

            Connections {
                target: root.amount ? root.amount : null
                function onDisplayChanged() {
                    amountInput.syncFromAmount(false)
                }
                function onUnitChanged() {
                    root.syncFromAmount(true)
                }
            }
        }

        Item {
            id: unitToggle
            width: unitLabel.width + flipIcon.width
            height: Math.max(unitLabel.height, flipIcon.height)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.enabled ? 1.0 : 0.5

            function click() {
                if (!root.enabled || !root.amount) return
                amountInput.commitAmountText()
                // Cycle only this field's unit; the persisted display unit
                // is changed from the settings page.
                root.amount.cycleUnit(optionsModel.defaultDisplayUnit)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.enabled && root.amount
                onClicked: parent.click()
            }

            CoreText {
                id: unitLabel
                anchors.right: flipIcon.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.amount ? root.amount.unitLabel : ""
                font: Theme.text.body.font
                lineHeight: Theme.text.body.lineHeight
                lineHeightMode: Text.FixedHeight
                color: root.enabled ? Theme.color.neutral7 : Theme.color.neutral4
            }

            Icon {
                id: flipIcon
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                source: "image://images/flip-vertical"
                color: enabled ? Theme.color.neutral8 : Theme.color.neutral4
                size: 30
            }
        }
    }

    RowLayout {
        id: errorRow
        Layout.fillWidth: true
        visible: root.errorText.length > 0

        Icon {
            source: "image://images/alert-filled"
            size: 22
            color: Theme.color.red
        }

        CoreText {
            id: errorTextLabel
            text: root.errorText
            font: Theme.text.description.font
            lineHeight: Theme.text.description.lineHeight
            lineHeightMode: Text.FixedHeight
            color: Theme.color.red
            horizontalAlignment: Text.AlignLeft
            Layout.fillWidth: true
        }
    }
}
