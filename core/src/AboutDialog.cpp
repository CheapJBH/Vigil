/*
 * AboutDialog.cpp - implementation of AboutDialog
 *
 * Copyright (c) 2011-2026 Tobias Junghans <tobydox@vigil.io>
 *
 * This file is part of Vigil - https://vigil.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#include <QDesktopServices>
#include <QFile>

#include "AboutDialog.h"
#include "VigilCore.h"

#include "ui_AboutDialog.h"


AboutDialog::AboutDialog( QWidget *parent ) :
	QDialog( parent ),
	ui( new Ui::AboutDialog )
{
	ui->setupUi( this );

	setWindowTitle(tr("About Vigil %1").arg(VigilCore::versionString()));

	ui->versionLabel->setText( VigilCore::versionString() );

	QFile authors( QStringLiteral( ":/CONTRIBUTORS" ) );
	if (authors.open(QFile::ReadOnly))
	{
		ui->authors->setPlainText(QString::fromUtf8(authors.readAll()));
	}

	QFile license( QStringLiteral( ":/core/COPYING" ) );
	if (license.open(QFile::ReadOnly))
	{
		ui->license->setPlainText(QString::fromUtf8(license.readAll()));
	}
}



AboutDialog::~AboutDialog()
{
	delete ui;
}



void AboutDialog::openDonationWebsite()
{
	  QDesktopServices::openUrl( QUrl( QStringLiteral( "https://www.paypal.com/cgi-bin/webscr?item_name=Donation+to+Vigil+-+OpenSource+classroom+management&cmd=_donations&business=donate%40vigil.io" ) ) );
}
