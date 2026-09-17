// Copyright (c) 2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQuick 2.15
import QtTest 1.2
import org.bitcoincore.qt 1.0
import "../../qml/components"

TestCase {
    id: root
    name: "AppFileDialog"

    Component {
        id: dialogComponent
        AppFileDialog {
            title: "Export activity"
            nameFilters: ["Comma separated file (*.csv)"]
            defaultSuffix: "csv"
            fileMode: AppFileDialog.SaveFile
            currentFolder: "file:///tmp"
            currentFile: "file:///tmp/out.csv"
        }
    }

    function test_save_dialog_reports_selection_and_dismissal() {
        const dialog = createTemporaryObject(dialogComponent, root)
        verify(dialog !== null)
        let acceptedCount = 0
        let rejectedCount = 0
        dialog.accepted.connect(function() { acceptedCount++ })
        dialog.rejected.connect(function() { rejectedCount++ })

        SystemFileDialog.nextSelectedFile = "file:///tmp/chosen.csv"
        dialog.open()
        tryVerify(function() { return acceptedCount === 1 })
        compare(dialog.selectedFile.toString(), "file:///tmp/chosen.csv")
        compare(SystemFileDialog.lastMode, "save")
        compare(SystemFileDialog.lastTitle, "Export activity")
        compare(SystemFileDialog.lastDefaultSuffix, "csv")
        compare(SystemFileDialog.lastFolder.toString(), "file:///tmp")
        compare(SystemFileDialog.lastFile.toString(), "file:///tmp/out.csv")
        compare(SystemFileDialog.lastNameFilters.length, 1)
        compare(SystemFileDialog.lastNameFilters[0], "Comma separated file (*.csv)")

        // A dismissed dialog reports rejection and leaves the selection alone.
        SystemFileDialog.nextSelectedFile = ""
        dialog.open()
        tryVerify(function() { return rejectedCount === 1 })
        compare(acceptedCount, 1)
        compare(dialog.selectedFile.toString(), "file:///tmp/chosen.csv")
    }

    function test_open_dialog_uses_the_load_path() {
        const dialog = createTemporaryObject(dialogComponent, root, { fileMode: AppFileDialog.OpenFile })
        verify(dialog !== null)
        let selected = ""
        dialog.accepted.connect(function() { selected = dialog.selectedFile.toString() })

        SystemFileDialog.nextSelectedFile = "file:///tmp/in.psbt"
        dialog.open()
        tryVerify(function() { return selected === "file:///tmp/in.psbt" })
        compare(SystemFileDialog.lastMode, "load")
    }
}
