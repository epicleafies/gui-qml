// Copyright (c) 2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQuick 2.15
import QtTest 1.2
import "../../qml/controls"
import "../../qml/components"

TestCase {
    id: testCase
    name: "ExternalSignerPathSection"
    when: windowShown
    visible: true
    width: 640
    height: 420

    property string motionMode: ""

    function init() {
        motionMode = Theme.motion.mode
        Theme.motion.mode = "full"
        walletController.reset()
        optionsModel.externalSignerPath = "/signer/signer.py"
        setStatus(true, 1, "trezor_t", "")
    }

    function cleanup() {
        Theme.motion.mode = motionMode
        optionsModel.externalSignerPath = ""
        walletController.reset()
    }

    function setStatus(responding, count, name, error) {
        walletController.externalSignerPathConfigured = true
        walletController.externalSignerResponding = responding
        walletController.externalSignerCount = count
        walletController.externalSignerName = name
        walletController.externalSignerError = error
        walletController.canCreateExternalSignerWallet = responding && count === 1 && error.length === 0
    }

    ExternalSignerPathSection {
        id: section
        width: 600
        namePrefix: "test"
    }

    // The most saturated pixel in a row is its status icon's.
    function iconPixel(row) {
        const image = grabImage(row)
        let best = null
        let bestSaturation = -1
        for (let x = 0; x < row.width; ++x) {
            for (let y = 0; y < row.height; ++y) {
                const pixel = image.pixel(x, y)
                const saturation = Math.max(pixel.r, pixel.g, pixel.b) - Math.min(pixel.r, pixel.g, pixel.b)
                if (pixel.a > 0.9 && saturation > bestSaturation) {
                    best = pixel
                    bestSaturation = saturation
                }
            }
        }
        return best
    }

    function compareIcon(rowName, expected) {
        const pixel = iconPixel(findChild(section, rowName))
        verify(Math.abs(pixel.r - expected.r) < 0.12 && Math.abs(pixel.g - expected.g) < 0.12
               && Math.abs(pixel.b - expected.b) < 0.12,
               rowName + " icon shows " + pixel + ", expected " + expected)
    }

    function test_iconsShowTheirStateAfterAPathChange() {
        wait(400)
        compareIcon("testCommandRow", Theme.color.successText)
        compareIcon("testDeviceRow", Theme.color.successText)

        // Pick another signer, as Browse does, then check it. The new
        // result arrives while the check runs.
        findChild(section, "testPathInput").text = "/signer/multi_signers.py"
        wait(400)
        section.check()
        setStatus(true, 2, "", "More than one external signer was found. Connect only one device.")
        wait(400)
        compareIcon("testCommandRow", Theme.color.successText)
        compareIcon("testDeviceRow", Theme.color.warningText)
    }
}
