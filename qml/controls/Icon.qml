// Copyright (c) 2023-2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQuick 2.15
import QtQuick.Controls 2.15

Button {
    id: root
    width: icon.width
    height: icon.height
    required property color color
    required property url source
    property int size: 32
    focusPolicy: Qt.NoFocus
    padding: 0
    icon.source: root.source
    icon.color: root.color
    icon.height: root.size
    icon.width: root.size
    enabled: false
    background: null
    // Decorative: the control that shows the icon carries the name.
    Accessible.ignored: true

    // A color set while the icon is hidden applies at once, so the icon
    // never comes back showing the color of a state it no longer shows.
    Behavior on icon.color {
        enabled: Theme.motion.animated && root.visible
        ColorAnimation {
            duration: Theme.motion.normal
        }
    }
}
