// Copyright (c) 2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#ifndef BITCOIN_QML_SYSTEMFILEDIALOG_H
#define BITCOIN_QML_SYSTEMFILEDIALOG_H

#include <QFileDialog>
#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QUrl>

// Bridges QML file choosing to the widgets QFileDialog. The QtQuick.Dialogs
// FileDialog cannot be used here: when the platform theme offers no native
// dialog its fallback needs the optional Qt.labs.folderlistmodel module, and
// on Qt 6.4 a failure to load that module crashes the application inside
// QQuickFileDialog::onCreate instead of degrading. QFileDialog prefers the
// same native dialog when one is available and otherwise falls back to its
// own widget implementation, which depends on nothing optional.
class SystemFileDialog : public QObject
{
    Q_OBJECT

public:
    explicit SystemFileDialog(QObject* parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE bool openSaveDialog(const QString& title, const QUrl& current_folder,
                                    const QUrl& current_file, const QStringList& name_filters,
                                    const QString& default_suffix)
    {
        QFileDialog* dialog = createDialog(title, current_folder, name_filters);
        if (!dialog) return false;
        dialog->setAcceptMode(QFileDialog::AcceptSave);
        if (!default_suffix.isEmpty()) {
            dialog->setDefaultSuffix(default_suffix);
        }
        const QString file_name = current_file.fileName();
        if (!file_name.isEmpty()) {
            dialog->selectFile(file_name);
        }
        dialog->open();
        return true;
    }

    Q_INVOKABLE bool openLoadDialog(const QString& title, const QUrl& current_folder,
                                    const QStringList& name_filters)
    {
        QFileDialog* dialog = createDialog(title, current_folder, name_filters);
        if (!dialog) return false;
        dialog->setAcceptMode(QFileDialog::AcceptOpen);
        dialog->setFileMode(QFileDialog::ExistingFile);
        dialog->open();
        return true;
    }

Q_SIGNALS:
    void fileSelected(const QUrl& file);
    void dismissed();

private:
    QFileDialog* createDialog(const QString& title, const QUrl& current_folder,
                              const QStringList& name_filters)
    {
        // One dialog at a time: the dialog is application modal, so a second
        // request while one is open can only come from a programming error.
        if (m_dialog) return nullptr;
        QFileDialog* dialog = new QFileDialog(nullptr, title);
        m_dialog = dialog;
        dialog->setAttribute(Qt::WA_DeleteOnClose);
        dialog->setWindowModality(Qt::ApplicationModal);
        if (!name_filters.isEmpty()) {
            dialog->setNameFilters(name_filters);
        }
        if (current_folder.isValid() && !current_folder.isEmpty()) {
            dialog->setDirectoryUrl(current_folder);
        }
        connect(dialog, &QDialog::accepted, this, [this, dialog] {
            const QList<QUrl> urls = dialog->selectedUrls();
            if (urls.isEmpty()) {
                Q_EMIT dismissed();
            } else {
                Q_EMIT fileSelected(urls.first());
            }
        });
        connect(dialog, &QDialog::rejected, this, [this] {
            Q_EMIT dismissed();
        });
        return dialog;
    }

    QPointer<QFileDialog> m_dialog;
};

#endif // BITCOIN_QML_SYSTEMFILEDIALOG_H
