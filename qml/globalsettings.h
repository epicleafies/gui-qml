// Copyright (c) 2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#ifndef BITCOIN_QML_GLOBALSETTINGS_H
#define BITCOIN_QML_GLOBALSETTINGS_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariant>

// QML's Settings store under the application name, which is set per
// chain. This reads and writes the settings shared by every chain.
class GlobalSettings : public QObject
{
    Q_OBJECT
public:
    explicit GlobalSettings(const QString& application, QObject* parent = nullptr)
        : QObject(parent), m_application(application) {}

    Q_INVOKABLE QVariant value(const QString& key, const QVariant& default_value = {}) const
    {
        return settings().value(key, default_value);
    }

    Q_INVOKABLE void setValue(const QString& key, const QVariant& value)
    {
        settings().setValue(key, value);
    }

private:
    QSettings settings() const
    {
        // The default identity resolves the organization the way QSettings{} does (the domain on macOS).
        const QSettings defaults;
        return QSettings{defaults.format(), defaults.scope(), defaults.organizationName(), m_application};
    }

    const QString m_application;
};

#endif // BITCOIN_QML_GLOBALSETTINGS_H
