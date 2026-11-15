// Copyright (c) 2019-2026 Tobias Junghans <tobydox@vigil.io>
// This file is part of Vigil - https://vigil.io
// SPDX-License-Identifier: LGPL-2.0-or-later

#pragma once

#include <QDialog>

#include "VigilCore.h"

namespace Ui {
class LdapBrowseDialog;
}

class LdapConfiguration;
class LdapBrowseModel;

class LdapBrowseDialog : public QDialog
{
	Q_OBJECT
public:
	explicit LdapBrowseDialog( const LdapConfiguration& configuration, QWidget* parent = nullptr );
	~LdapBrowseDialog() override;

	QString browseBaseDn( const QString& dn );
	QString browseDn( const QString& dn );
	QString browseAttribute( const QString& dn );

private:
	QString browse( LdapBrowseModel* model, const QString& dn, bool expandSelected );

	Ui::LdapBrowseDialog* ui;
	const LdapConfiguration& m_configuration;

};
