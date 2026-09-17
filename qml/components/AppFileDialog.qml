// Copyright (c) 2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQml 2.15
import org.bitcoincore.qt 1.0

// Stand-in for the QtQuick.Dialogs FileDialog backed by the widgets
// QFileDialog through the SystemFileDialog bridge. The Quick dialog's
// non-native fallback needs the optional Qt.labs.folderlistmodel module,
// and on Qt 6.4 a failure to load it crashes the whole application the
// moment the dialog opens.
QtObject {
    id: root

    enum FileMode {
        OpenFile,
        SaveFile
    }

    property int fileMode: AppFileDialog.OpenFile
    property string title: ""
    property var nameFilters: []
    property string defaultSuffix: ""
    property url currentFolder
    property url currentFile
    property url selectedFile

    // Whether this instance opened the dialog the shared bridge is showing;
    // only that instance may consume the bridge's result signals.
    property bool active: false

    signal accepted()
    signal rejected()

    function open() {
        if (root.fileMode === AppFileDialog.SaveFile) {
            root.active = SystemFileDialog.openSaveDialog(
                root.title, root.currentFolder, root.currentFile,
                root.nameFilters, root.defaultSuffix)
        } else {
            root.active = SystemFileDialog.openLoadDialog(
                root.title, root.currentFolder, root.nameFilters)
        }
    }

    property Connections _bridge: Connections {
        target: SystemFileDialog
        function onFileSelected(file) {
            if (!root.active) return
            root.active = false
            root.selectedFile = file
            root.accepted()
        }
        function onDismissed() {
            if (!root.active) return
            root.active = false
            root.rejected()
        }
    }
}
