// Copyright (c) 2023 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.0
import org.bitcoincore.qt 1.0
import "../controls"

Popup {
    id: externalConfirmPopup
    objectName: "externalPopup"
    property string link: ""
    property string popupState: "confirm"
    modal: true
    padding: 0
    anchors.centerIn: parent
    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    onOpened: {
        popupState = "confirm"
        successDismissTimer.stop()
        copyFeedbackTimer.stop()
        copyIcon.showCheck = false
        confirmCopyIcon.showCheck = false
    }

    function tryOpenUrl() {
        if (Qt.openUrlExternally(link)) {
            popupState = "success"
            successDismissTimer.start()
        } else {
            popupState = "failure"
        }
    }

    Timer {
        id: successDismissTimer
        interval: 800
        repeat: false
        onTriggered: externalConfirmPopup.close()
    }

    Timer {
        id: confirmCopyTimer
        interval: 2000
        repeat: false
        onTriggered: confirmCopyIcon.showCheck = false
    }

    Timer {
        id: copyFeedbackTimer
        interval: 2000
        repeat: false
        onTriggered: copyIcon.showCheck = false
    }

    background: Rectangle {
        color: Theme.color.background
        radius: 10
        border.color: Theme.color.neutral3
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        CoreText {
            Layout.fillWidth: true
            Layout.preferredHeight: 55
            text: qsTr("External Link")
            bold: true
            font.pixelSize: 24
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Separator {
            Layout.fillWidth: true
        }

        ColumnLayout {
            visible: externalConfirmPopup.popupState === "confirm"
            spacing: 0

            CoreText {
                Layout.fillWidth: true
                Layout.margins: 20
                Layout.topMargin: 20
                Layout.bottomMargin: 12
                text: qsTr("Do you want to open the following website in your browser?")
                font.pixelSize: 16
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.bottomMargin: 20
                color: Theme.color.neutral2
                radius: 5
                implicitHeight: confirmUrlContent.implicitHeight + 24

                RowLayout {
                    id: confirmUrlContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    CoreText {
                        text: externalConfirmPopup.link
                        font.family: Theme.text.monoCaption.family
                        font.pixelSize: 13
                        color: Theme.color.neutral9
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.WrapAnywhere
                        Layout.fillWidth: true
                    }

                    Icon {
                        id: confirmCopyIcon
                        property bool showCheck: false
                        source: showCheck ? "image://images/check" : "image://images/copy"
                        color: showCheck ? Theme.color.green : Theme.color.neutral7
                        size: 20
                        enabled: true
                        onClicked: {
                            Clipboard.setText(externalConfirmPopup.link)
                            showCheck = true
                            confirmCopyTimer.restart()
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                Layout.topMargin: 0
                columns: AppMode.isDesktop ? 2 : 1
                columnSpacing: 15
                rowSpacing: 10

                OutlineButton {
                    objectName: "externalPopupCancel"
                    text: qsTr("Cancel")
                    Layout.fillWidth: true
                    Layout.minimumWidth: 120
                    onClicked: externalConfirmPopup.close()
                }

                ContinueButton {
                    objectName: "externalPopupOk"
                    text: qsTr("Ok")
                    Layout.fillWidth: true
                    Layout.minimumWidth: 120
                    onClicked: externalConfirmPopup.tryOpenUrl()
                }
            }
        }

        ColumnLayout {
            visible: externalConfirmPopup.popupState === "failure"
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 20
                Layout.bottomMargin: 0
                color: Theme.color.dangerBackground
                radius: 5
                border.width: 1
                border.color: Qt.rgba(Theme.color.red.r, Theme.color.red.g, Theme.color.red.b, 0.3)
                implicitHeight: bannerContent.implicitHeight + 24

                RowLayout {
                    id: bannerContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Icon {
                        source: "image://images/alert-circle"
                        color: Theme.color.red
                        size: 24
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        CoreText {
                            text: qsTr("Couldn't open link")
                            bold: true
                            font.pixelSize: 15
                            color: Theme.color.red
                            horizontalAlignment: Text.AlignLeft
                            Layout.fillWidth: true
                        }

                        CoreText {
                            text: qsTr("No default browser is set, or it refused the request.")
                            font.pixelSize: 13
                            color: Theme.color.neutral7
                            horizontalAlignment: Text.AlignLeft
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            CoreText {
                Layout.fillWidth: true
                Layout.margins: 20
                Layout.bottomMargin: 8
                text: qsTr("Copy the link and open it manually, or try again:")
                font.pixelSize: 15
                color: Theme.color.neutral7
                horizontalAlignment: Text.AlignLeft
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: Theme.color.neutral2
                radius: 5
                implicitHeight: urlContent.implicitHeight + 24

                RowLayout {
                    id: urlContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    CoreText {
                        objectName: "externalPopupUrl"
                        text: externalConfirmPopup.link
                        font.family: Theme.text.monoCaption.family
                        font.pixelSize: 13
                        color: Theme.color.neutral9
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.WrapAnywhere
                        Layout.fillWidth: true
                    }

                    Icon {
                        id: copyIcon
                        objectName: "externalPopupCopy"
                        property bool showCheck: false
                        source: showCheck ? "image://images/check" : "image://images/copy"
                        color: showCheck ? Theme.color.green : Theme.color.neutral7
                        size: 20
                        enabled: true
                        onClicked: {
                            Clipboard.setText(externalConfirmPopup.link)
                            showCheck = true
                            copyFeedbackTimer.restart()
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                columns: AppMode.isDesktop ? 2 : 1
                columnSpacing: 15
                rowSpacing: 10

                OutlineButton {
                    objectName: "externalPopupClose"
                    text: qsTr("Close")
                    Layout.fillWidth: true
                    Layout.minimumWidth: 120
                    onClicked: externalConfirmPopup.close()
                }

                ContinueButton {
                    objectName: "externalPopupRetry"
                    text: qsTr("Try again")
                    Layout.fillWidth: true
                    Layout.minimumWidth: 120
                    onClicked: externalConfirmPopup.tryOpenUrl()
                }
            }
        }

        ColumnLayout {
            visible: externalConfirmPopup.popupState === "success"
            spacing: 10
            Layout.margins: 30
            Layout.alignment: Qt.AlignHCenter

            Icon {
                source: "image://images/circle-green-check"
                color: Theme.color.green
                size: 32
                Layout.alignment: Qt.AlignHCenter
            }

            CoreText {
                text: qsTr("Opened in browser")
                font.pixelSize: 15
                color: Theme.color.neutral7
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }
}
