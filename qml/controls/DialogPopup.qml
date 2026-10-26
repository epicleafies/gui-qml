// Copyright (c) 2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQml 2.15
import QtQuick 2.15
import QtQuick.Controls 2.15

// Shared shell for modal dialogs: alerts (AlertPopup), feature modals and
// sheets. It centers on the window unless the caller passes a container as
// `parent`.
Popup {
    id: root

    property string title: ""
    // Modals hosting a multi-step flow use the larger sheet radius.
    property bool sheet: false
    // Escape closes the popup. Alerts handle Escape themselves.
    property bool dismissible: true
    // Pressing outside closes the popup: feature modals only, never alerts
    // or input dialogs.
    property bool closesOnPressOutside: true
    // Nothing closes the popup while busy.
    property bool busy: false
    // Receives keyboard focus once the popup is open; defaults to the content.
    property Item initialFocusItem: null
    // The item that had focus before the popup opened; focus returns there on close.
    property Item returnFocusItem: null
    property string surfaceObjectName: "dialogPopupSurface"
    property real verticalOffset: 0
    // Start offset of the enter transition; the exit always travels up.
    property real enterOffset: -Theme.motion.dialogOffset
    property real exitOffset: -Theme.motion.dialogOffset
    readonly property real edgeMargin: Theme.space.xl
    // Only an open popup fits itself to its parent. Before Overlay.overlay
    // exists the parent can be a temporary item, and on Qt 6.5 and older
    // fitting a closed popup to it loops on the height binding, since the
    // content layout is not polished while the popup is closed.
    readonly property bool fitsParent: visible && parent !== null
    readonly property real maximumHeight: fitsParent ? parent.height - 2 * edgeMargin : implicitHeight
    readonly property bool compact: parent ? SizeClass.isCompact(parent.width) : false

    parent: Overlay.overlay
    modal: true
    dim: true
    focus: true
    closePolicy: busy || !dismissible
        ? Popup.NoAutoClose
        : closesOnPressOutside ? Popup.CloseOnEscape | Popup.CloseOnPressOutside : Popup.CloseOnEscape
    padding: Theme.space.xxxl
    horizontalPadding: compact ? Theme.space.xxl : Theme.space.page
    width: fitsParent ? Math.min(implicitWidth, parent.width - 2 * edgeMargin) : implicitWidth
    height: Math.min(implicitHeight, maximumHeight)
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) + verticalOffset : verticalOffset

    Overlay.modal: Rectangle {
        objectName: "dialogPopupDimmer"
        color: Theme.color.modalOverlay
        Behavior on opacity {
            enabled: Theme.motion.animated
            NumberAnimation {
                duration: Theme.motion.fade(Theme.motion.exit)
                easing.type: Theme.motion.easing.move
            }
        }
    }

    background: Rectangle {
        objectName: root.surfaceObjectName
        color: Theme.color.surface1
        radius: root.sheet ? Theme.radius.sheet : Theme.radius.popup
        border.color: root.sheet ? Theme.color.surface3 : Theme.color.surface2
        border.width: 1
        SurfaceGradientBorder {
            anchors.fill: parent
            surfaceColor: parent.color
            cornerRadius: parent.radius
        }
    }

    enter: Theme.motion.animated ? enterTransition : null
    exit: Theme.motion.animated ? exitTransition : null

    // No `from:` values: an interrupted transition continues from where it is.
    // onAboutToShow sets the start state of a fresh enter.
    property Transition enterTransition: Transition {
        NumberAnimation {
            property: "opacity"
            to: 1
            duration: Theme.motion.fade(Theme.motion.slow)
            easing.type: Theme.motion.easing.enter
        }
        NumberAnimation {
            property: "verticalOffset"
            to: 0
            duration: Theme.motion.travel(Theme.motion.slow)
            easing.type: Theme.motion.easing.enter
        }
    }

    property Transition exitTransition: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: Theme.motion.fade(Theme.motion.exit)
            easing.type: Theme.motion.easing.exit
        }
        NumberAnimation {
            property: "verticalOffset"
            to: Theme.motion.reduced ? 0 : root.exitOffset
            duration: Theme.motion.travel(Theme.motion.exit)
            easing.type: Theme.motion.easing.exit
        }
    }

    property bool exiting: false

    // Accessible only attaches to items, so name the popup's own item.
    // Not Binding children: those would land in contentData and create a
    // default content item before subclasses set theirs.
    function updateAccessibility() {
        if (!popupItem) return
        popupItem.Accessible.role = Accessible.Dialog
        popupItem.Accessible.name = title
    }
    onTitleChanged: updateAccessibility()
    onPopupItemChanged: updateAccessibility()
    Component.onCompleted: updateAccessibility()

    readonly property Item popupItem: contentItem ? contentItem.parent : null

    function contains(item) {
        for (let it = item; it; it = it.parent) {
            if (it === popupItem) return true
        }
        return false
    }

    function popupItemOf(item) {
        const overlay = Overlay.overlay
        for (let it = item; it; it = it.parent) {
            if (it.parent === overlay) return it
        }
        return null
    }

    function focusContent() {
        const target = initialFocusItem ? initialFocusItem : contentItem
        if (target) target.forceActiveFocus(Qt.PopupFocusReason)
    }

    onAboutToShow: {
        const window = contentItem ? contentItem.Window.window : null
        const focused = window ? window.activeFocusItem : null
        if (focused && !contains(focused)) {
            returnFocusItem = focused
        }
        if (!enter) {
            opacity = 1
            verticalOffset = 0
        } else if (!exiting) {
            opacity = 0
            verticalOffset = Theme.motion.reduced ? 0 : enterOffset
        }
        exiting = false
    }
    onOpened: focusContent()
    onAboutToHide: exiting = true
    onClosed: {
        exiting = false
        const target = returnFocusItem
        returnFocusItem = null
        if (!target || !target.visible || !target.enabled) return
        const window = target.Window.window
        const focused = window ? window.activeFocusItem : null
        // Leave focus alone when it already moved on to another open popup.
        if (focused && popupItemOf(focused) !== popupItemOf(target)) return
        target.forceActiveFocus(Qt.OtherFocusReason)
    }
}
