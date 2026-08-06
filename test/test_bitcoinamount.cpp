// Copyright (c) 2025-2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <QtTest/QtTest>

#include <qml/bitcoinamount.h>

#include <limits>

#include <QRegularExpression>

class BitcoinAmountTests : public QObject {
    Q_OBJECT

private Q_SLOTS:
    void satsToBtcString_basic();
    void satsToBtcString_negative();
    void btcToSats_roundtrip();
    void fromDisplay_saturatesAtFactorBoundary();
    void sanitize_clampsAndFilters();
    void display_flow_btc();
    void display_flow_mbtc_and_ubtc();
    void display_flow_sat();
    void displayWithUnit_formatsAmountAndUnit();
    void flipUnit_changesLabelAndDisplaySignal();
    void inputRules_followUnit();
    void fromDisplayUnit_mapsAndClampsToBtc();
};

void BitcoinAmountTests::satsToBtcString_basic()
{
    QCOMPARE(BitcoinAmount::satsToBtcString(0), QString("0.00000000"));
    QCOMPARE(BitcoinAmount::satsToBtcString(1), QString("0.00000001"));
    QCOMPARE(BitcoinAmount::satsToBtcString(COIN), QString("1.00000000"));
    QCOMPARE(BitcoinAmount::satsToBtcString(21 * COIN), QString("21.00000000"));
    QCOMPARE(BitcoinAmount::satsToBtcString(100000123), QString("1.00000123"));
}

void BitcoinAmountTests::satsToBtcString_negative()
{
    QCOMPARE(BitcoinAmount::satsToBtcString(-1), QString("-0.00000001"));
}

void BitcoinAmountTests::btcToSats_roundtrip()
{
    BitcoinAmount amt;
    amt.setUnit(BitcoinAmount::Unit::BTC);
    amt.fromDisplay("1.23456789");
    QCOMPARE(amt.toDisplay(), QString("1.23456789"));
}

void BitcoinAmountTests::fromDisplay_saturatesAtFactorBoundary()
{
    // A whole part equal to qint64 max / factor used to pass the overflow
    // guard, so whole * factor + frac overflowed. It must saturate instead;
    // the result stays above MAX_MONEY, keeping amount validation intact.
    BitcoinAmount amt;
    amt.setUnit(BitcoinAmount::Unit::BTC);
    amt.fromDisplay("92233720368.99999999");
    QCOMPARE(amt.satoshi(), std::numeric_limits<qint64>::max());

    amt.setUnit(BitcoinAmount::Unit::uBTC);
    amt.fromDisplay("92233720368547758.99");
    QCOMPARE(amt.satoshi(), std::numeric_limits<qint64>::max());
}

void BitcoinAmountTests::sanitize_clampsAndFilters()
{
    BitcoinAmount amt;
    amt.setUnit(BitcoinAmount::Unit::BTC);
    amt.fromDisplay("abc1.2.3xyz");
    QCOMPARE(amt.toDisplay(), QString("1.20000000"));
}

void BitcoinAmountTests::display_flow_btc()
{
    BitcoinAmount amt;
    amt.setUnit(BitcoinAmount::Unit::BTC);
    amt.setSatoshi(2 * COIN);
    QCOMPARE(amt.toDisplay(), QString("2.00000000"));
}

void BitcoinAmountTests::display_flow_mbtc_and_ubtc()
{
    BitcoinAmount amt;
    amt.setUnit(BitcoinAmount::Unit::mBTC);
    amt.setSatoshi(COIN);
    QCOMPARE(amt.toDisplay(), QString("1000.00000"));
    QCOMPARE(amt.unitLabel(), QString("mBTC"));

    amt.fromDisplay("1.23456789");
    QCOMPARE(amt.satoshi(), qint64{123456});
    QCOMPARE(amt.toDisplay(), QString("1.23456"));

    amt.setUnit(BitcoinAmount::Unit::uBTC);
    QCOMPARE(amt.toDisplay(), QString("1234.56"));
    QCOMPARE(amt.unitLabel(), QString("bits"));

    amt.fromDisplay("1.239");
    QCOMPARE(amt.satoshi(), qint64{123});
    QCOMPARE(amt.toDisplay(), QString("1.23"));
}

void BitcoinAmountTests::display_flow_sat()
{
    BitcoinAmount amt;
    amt.setUnit(BitcoinAmount::Unit::SAT);
    amt.setSatoshi(123);
    QCOMPARE(amt.toDisplay(), QString("123"));
}

void BitcoinAmountTests::displayWithUnit_formatsAmountAndUnit()
{
    BitcoinAmount amt;
    QVERIFY(amt.displayWithUnit().isEmpty());

    amt.setSatoshi(COIN);
    QCOMPARE(amt.displayWithUnit(), QStringLiteral("1.00000000 ₿"));

    amt.setUnit(BitcoinAmount::Unit::SAT);
    QCOMPARE(amt.displayWithUnit(), QStringLiteral("100000000 sats"));

    amt.setSatoshi(1);
    QCOMPARE(amt.displayWithUnit(), QStringLiteral("1 sat"));
}

void BitcoinAmountTests::flipUnit_changesLabelAndDisplaySignal()
{
    BitcoinAmount amt;
    amt.setSatoshi(100);
    QSignalSpy spy(&amt, &BitcoinAmount::displayChanged);
    amt.flipUnit();
    QVERIFY(spy.count() >= 1);
}

void BitcoinAmountTests::inputRules_followUnit()
{
    BitcoinAmount amt;

    amt.setUnit(BitcoinAmount::Unit::BTC);
    QCOMPARE(amt.inputPlaceholder(), QString("0.00000000"));
    QCOMPARE(amt.maximumInputLength(), 17);
    QVERIFY(QRegularExpression(amt.inputPattern()).match("20999999.99999999").hasMatch());
    // Transient editing state: typing in front of "0.xxx" goes through "01.xxx".
    QVERIFY(QRegularExpression(amt.inputPattern()).match("01.00000000").hasMatch());
    QVERIFY(!QRegularExpression(amt.inputPattern()).match("1.234567890").hasMatch());

    amt.setUnit(BitcoinAmount::Unit::mBTC);
    QCOMPARE(amt.inputPlaceholder(), QString("0.00000"));
    QCOMPARE(amt.maximumInputLength(), 17);
    QVERIFY(QRegularExpression(amt.inputPattern()).match("20999999999.99999").hasMatch());
    QVERIFY(!QRegularExpression(amt.inputPattern()).match("1.234567").hasMatch());

    amt.setUnit(BitcoinAmount::Unit::uBTC);
    QCOMPARE(amt.inputPlaceholder(), QString("0.00"));
    QCOMPARE(amt.maximumInputLength(), 17);
    QVERIFY(QRegularExpression(amt.inputPattern()).match("20999999999999.99").hasMatch());
    QVERIFY(!QRegularExpression(amt.inputPattern()).match("1.234").hasMatch());

    amt.setUnit(BitcoinAmount::Unit::SAT);
    QCOMPARE(amt.inputPlaceholder(), QString("0"));
    QCOMPARE(amt.maximumInputLength(), 16);
    QVERIFY(QRegularExpression(amt.inputPattern()).match("2099999999999999").hasMatch());
    QVERIFY(!QRegularExpression(amt.inputPattern()).match("1.2").hasMatch());
}

void BitcoinAmountTests::fromDisplayUnit_mapsAndClampsToBtc()
{
    QCOMPARE(BitcoinAmount::fromDisplayUnit(0), BitcoinAmount::Unit::BTC);
    QCOMPARE(BitcoinAmount::fromDisplayUnit(1), BitcoinAmount::Unit::mBTC);
    QCOMPARE(BitcoinAmount::fromDisplayUnit(2), BitcoinAmount::Unit::uBTC);
    QCOMPARE(BitcoinAmount::fromDisplayUnit(3), BitcoinAmount::Unit::SAT);
    QCOMPARE(BitcoinAmount::fromDisplayUnit(-1), BitcoinAmount::Unit::BTC);
    QCOMPARE(BitcoinAmount::fromDisplayUnit(99), BitcoinAmount::Unit::BTC);
}

#ifdef BITCOINQML_NO_TEST_MAIN
#include <test/qt_test_registry.h>
BITCOINQML_REGISTER_QT_TEST(BitcoinAmountTests)
#else
QTEST_MAIN(BitcoinAmountTests)
#endif
#include "test_bitcoinamount.moc"
