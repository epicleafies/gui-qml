// Copyright (c) 2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <QtTest/QtTest>

#include <test/mocks/mockwallet.h>
#include <qml/models/bumptransactionmodel.h>

#include <QLocale>
#include <QScopeGuard>
#include <QSignalSpy>

#include <memory>

namespace {
const auto TEST_TXID = QStringLiteral("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");

std::unique_ptr<MockWallet> MakeBumpableWallet()
{
    auto wallet = std::make_unique<MockWallet>();
    wallet->transaction_can_be_bumped_fn = [](const Txid&) { return true; };
    return wallet;
}
} // namespace

class BumpTransactionModelTests : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void stateIsIdleByDefault()
    {
        auto wallet = MakeBumpableWallet();
        BumpTransactionModel model(wallet.get());
        QCOMPARE(model.state(), BumpTransactionModel::Idle);
    }

    void prepareFeeBump_transitionsToNeedsConfirmation()
    {
        auto wallet = MakeBumpableWallet();
        wallet->create_bump_transaction_fn = [](const Txid&, const wallet::CCoinControl&, std::vector<bilingual_str>&,
                                                CAmount& old_fee, CAmount& new_fee, CMutableTransaction&) {
            old_fee = 500;
            new_fee = 1000;
            return true;
        };

        BumpTransactionModel model(wallet.get());
        QSignalSpy stateSpy(&model, &BumpTransactionModel::stateChanged);

        model.prepareFeeBump(TEST_TXID, 1);

        QCOMPARE(model.state(), BumpTransactionModel::NeedsConfirmation);
        QVERIFY(stateSpy.count() >= 2); // Idle -> Preparing -> NeedsConfirmation
    }

    void prepareFeeBump_populatesFees()
    {
        auto wallet = MakeBumpableWallet();
        wallet->create_bump_transaction_fn = [](const Txid&, const wallet::CCoinControl&, std::vector<bilingual_str>&,
                                                CAmount& old_fee, CAmount& new_fee, CMutableTransaction&) {
            old_fee = 500;
            new_fee = 1000;
            return true;
        };

        const QLocale previous_locale;
        const auto restore_locale = qScopeGuard([previous_locale] { QLocale::setDefault(previous_locale); });
        QLocale::setDefault(QLocale{"en_US"});

        BumpTransactionModel model(wallet.get());
        model.prepareFeeBump(TEST_TXID, 1);

        QCOMPARE(model.oldFee(), QStringLiteral("0.00000500 BTC"));
        QCOMPARE(model.newFee(), QStringLiteral("0.00001000 BTC"));
        QCOMPARE(model.feeIncrease(), QStringLiteral("0.00000500 BTC"));

        // The formatted fees follow the display unit.
        QSignalSpy result_spy(&model, &BumpTransactionModel::resultChanged);
        model.setDisplayUnit(3);
        QCOMPARE(result_spy.count(), 1);
        QCOMPARE(model.oldFee(), QStringLiteral("500 sats"));
        QCOMPARE(model.newFee(), QStringLiteral("1,000 sats"));
        QCOMPARE(model.feeIncrease(), QStringLiteral("500 sats"));
        model.setDisplayUnit(2);
        QCOMPARE(model.newFee(), QStringLiteral("10.00 bits"));
        model.setDisplayUnit(2);
        QCOMPARE(result_spy.count(), 2);
    }

    void prepareFeeBump_failureSetsErrorState()
    {
        auto wallet = MakeBumpableWallet();
        wallet->create_bump_transaction_fn = [](const Txid&, const wallet::CCoinControl&, std::vector<bilingual_str>& errors,
                                                CAmount&, CAmount&, CMutableTransaction&) {
            errors.emplace_back(Untranslated("insufficient fee"));
            return false;
        };

        BumpTransactionModel model(wallet.get());
        model.prepareFeeBump(TEST_TXID, 1);

        QCOMPARE(model.state(), BumpTransactionModel::Failed);
        QVERIFY(!model.errorText().isEmpty());
    }

    void prepareFeeBump_invalidTxidFails()
    {
        auto wallet = MakeBumpableWallet();
        BumpTransactionModel model(wallet.get());

        model.prepareFeeBump(QStringLiteral("not-a-txid"), 1);

        QCOMPARE(model.state(), BumpTransactionModel::Failed);
    }

    void prepareFeeBump_nullWalletFails()
    {
        BumpTransactionModel model(nullptr);

        model.prepareFeeBump(TEST_TXID, 1);

        QCOMPARE(model.state(), BumpTransactionModel::Failed);
    }

    void confirmFeeBump_signsAndCommits()
    {
        auto wallet = MakeBumpableWallet();
        wallet->create_bump_transaction_fn = [](const Txid&, const wallet::CCoinControl&, std::vector<bilingual_str>&,
                                                CAmount& old_fee, CAmount& new_fee, CMutableTransaction&) {
            old_fee = 500;
            new_fee = 1000;
            return true;
        };
        wallet->sign_bump_transaction_fn = [](CMutableTransaction&) { return true; };
        wallet->commit_bump_transaction_fn = [](const Txid&, CMutableTransaction&&, std::vector<bilingual_str>&, Txid& bumped_txid) {
            bumped_txid = Txid::FromUint256(*uint256::FromHex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"));
            return true;
        };

        BumpTransactionModel model(wallet.get());
        model.prepareFeeBump(TEST_TXID, 1);
        QCOMPARE(model.state(), BumpTransactionModel::NeedsConfirmation);

        model.confirmFeeBump();

        QCOMPARE(model.state(), BumpTransactionModel::Succeeded);
        QVERIFY(!model.newTxid().isEmpty());
    }

    void confirmFeeBump_signFailureDoesNotCommit()
    {
        auto wallet = MakeBumpableWallet();
        wallet->create_bump_transaction_fn = [](const Txid&, const wallet::CCoinControl&, std::vector<bilingual_str>&,
                                                CAmount& old_fee, CAmount& new_fee, CMutableTransaction&) {
            old_fee = 500;
            new_fee = 1000;
            return true;
        };
        wallet->sign_bump_transaction_fn = [](CMutableTransaction&) { return false; };

        BumpTransactionModel model(wallet.get());
        model.prepareFeeBump(TEST_TXID, 1);

        model.confirmFeeBump();

        QCOMPARE(model.state(), BumpTransactionModel::Failed);
        QCOMPARE(wallet->calls.commitBumpTransaction.load(), 0);
    }

    void confirmFeeBump_rejectsWhenNotReady()
    {
        auto wallet = MakeBumpableWallet();
        BumpTransactionModel model(wallet.get());

        model.confirmFeeBump();

        QCOMPARE(model.state(), BumpTransactionModel::Idle);
    }

    void confirmFeeBump_rechecksEligibility()
    {
        auto wallet = MakeBumpableWallet();
        wallet->create_bump_transaction_fn = [](const Txid&, const wallet::CCoinControl&, std::vector<bilingual_str>&,
                                                CAmount& old_fee, CAmount& new_fee, CMutableTransaction&) {
            old_fee = 500;
            new_fee = 1000;
            return true;
        };

        BumpTransactionModel model(wallet.get());
        model.prepareFeeBump(TEST_TXID, 1);

        wallet->transaction_can_be_bumped_fn = [](const Txid&) { return false; };
        model.confirmFeeBump();

        QCOMPARE(model.state(), BumpTransactionModel::Failed);
    }

    void reset_clearsState()
    {
        auto wallet = MakeBumpableWallet();
        wallet->create_bump_transaction_fn = [](const Txid&, const wallet::CCoinControl&, std::vector<bilingual_str>&,
                                                CAmount& old_fee, CAmount& new_fee, CMutableTransaction&) {
            old_fee = 500;
            new_fee = 1000;
            return true;
        };

        BumpTransactionModel model(wallet.get());
        model.prepareFeeBump(TEST_TXID, 1);
        QCOMPARE(model.state(), BumpTransactionModel::NeedsConfirmation);

        model.reset();

        QCOMPARE(model.state(), BumpTransactionModel::Idle);
        QVERIFY(model.newTxid().isEmpty());
        QVERIFY(model.errorText().isEmpty());
    }
};

#ifdef BITCOINQML_NO_TEST_MAIN
#include <test/qt_test_registry.h>
BITCOINQML_REGISTER_QT_TEST(BumpTransactionModelTests)
#else
QTEST_MAIN(BumpTransactionModelTests)
#endif
#include "test_bumptransactionmodel.moc"
