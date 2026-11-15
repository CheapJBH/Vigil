/*
 * GeneralConfigurationPage.cpp - configuration page with general settings
 *
 * Copyright (c) 2016-2026 Tobias Junghans <tobydox@vigil.io>
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

#include <QDir>
#include <QMessageBox>

#include "AuthenticationCredentials.h"
#include "Configuration/UiMapping.h"
#include "GeneralConfigurationPage.h"
#include "Filesystem.h"
#include "FileSystemBrowser.h"
#include "NetworkObjectDirectoryManager.h"
#include "PlatformFilesystemFunctions.h"
#include "PlatformUserFunctions.h"
#include "PluginManager.h"
#include "VigilServiceControl.h"
#include "VigilCore.h"
#include "VigilConfiguration.h"
#include "UserGroupsBackendManager.h"

#include "ui_GeneralConfigurationPage.h"


GeneralConfigurationPage::GeneralConfigurationPage() :
	ConfigurationPage(),
	ui(new Ui::GeneralConfigurationPage)
{
	ui->setupUi(this);

	// retrieve list of builtin translations and populate language combobox
	QStringList languages;
	const auto qmFiles = QDir( VigilCore::translationsDirectory() ).entryList( { QStringLiteral("vigil*.qm") } );

	languages.reserve( qmFiles.count() );

	for( const auto& qmFile : qmFiles )
	{
		QLocale loc( qmFile.split( QLatin1Char('_') ).mid( 1 ).join( QLatin1Char('_') ) );
		if( loc.language() == QLocale::C )
		{
			loc = QLocale( QLocale::English );
		}
		languages += QStringLiteral( "%1 - %2 (%3)" ).arg( QLocale::languageToString( loc.language() ),
														   loc.nativeLanguageName(),
														   loc.name() );
	}

	std::sort( languages.begin(), languages.end() );

	ui->uiLanguage->addItems( languages );

	const auto backends = VigilCore::userGroupsBackendManager().availableBackends();
	if (backends.count() <= 0)
	{
		QMessageBox::critical(this,
							  tr("Missing user groups backend"),
							  tr("No user groups plugin was found. Please check your installation!"));
		qFatal("GeneralConfigurationPage: missing user groups backend");
	}

	for (auto it = backends.constBegin(), end = backends.constEnd(); it != end; ++it)
	{
		ui->userGroupsBackend->addItem(it.value(), it.key());
	}

	connect( ui->testAuthenticationButton, &QPushButton::clicked, this, &GeneralConfigurationPage::testAuthentication );
	connect( ui->openLogFileDirectory, &QPushButton::clicked, this, &GeneralConfigurationPage::openLogFileDirectory );
	connect( ui->clearLogFiles, &QPushButton::clicked, this, &GeneralConfigurationPage::clearLogFiles );
	connect( ui->userGroupsBackend, QOverload<int>::of(&QComboBox::currentIndexChanged), this, [this]() {
		const auto plugin = VigilCore::pluginManager().pluginInterface(ui->userGroupsBackend->currentData().toUuid());
		ui->useDomainUserGroups->setEnabled(plugin && plugin->flags().testFlag(Plugin::ProvidesDefaultImplementation));
	});

	populateNetworkObjectDirectories();
}



GeneralConfigurationPage::~GeneralConfigurationPage()
{
	delete ui;
}



void GeneralConfigurationPage::resetWidgets()
{
	FOREACH_VIGIL_UI_CONFIG_PROPERTY(INIT_WIDGET_FROM_PROPERTY);
	FOREACH_VIGIL_LOGGING_CONFIG_PROPERTY(INIT_WIDGET_FROM_PROPERTY);
	FOREACH_VIGIL_NETWORK_OBJECT_DIRECTORY_CONFIG_PROPERTY(INIT_WIDGET_FROM_PROPERTY);
	FOREACH_VIGIL_USER_GROUPS_BACKEND_CONFIG_PROPERTY(INIT_WIDGET_FROM_PROPERTY);
	FOREACH_VIGIL_AUTHENTICATION_CONFIG_PROPERTY(INIT_WIDGET_FROM_PROPERTY);
}



void GeneralConfigurationPage::connectWidgetsToProperties()
{
	FOREACH_VIGIL_UI_CONFIG_PROPERTY(CONNECT_WIDGET_TO_PROPERTY);
	FOREACH_VIGIL_LOGGING_CONFIG_PROPERTY(CONNECT_WIDGET_TO_PROPERTY);
	FOREACH_VIGIL_NETWORK_OBJECT_DIRECTORY_CONFIG_PROPERTY(CONNECT_WIDGET_TO_PROPERTY);
	FOREACH_VIGIL_USER_GROUPS_BACKEND_CONFIG_PROPERTY(CONNECT_WIDGET_TO_PROPERTY);
	FOREACH_VIGIL_AUTHENTICATION_CONFIG_PROPERTY(CONNECT_WIDGET_TO_PROPERTY);
}



void GeneralConfigurationPage::applyConfiguration()
{
	VigilCore::userGroupsBackendManager().reloadConfiguration();
}



void GeneralConfigurationPage::testAuthentication()
{
	switch( VigilCore::config().authenticationMethod() )
	{
	case VigilCore::AuthenticationMethod::LogonAuthentication:
		if( testLogonAuthentication() == false )
		{
			return;
		}
		break;
	case VigilCore::AuthenticationMethod::KeyFileAuthentication:
		if( testKeyFileAuthentication() == false )
		{
			return;
		}
		break;
	}

	QMessageBox::information( this, authenticationTestTitle(),
							  tr( "Authentication is set up properly on this computer." ) );
}



bool GeneralConfigurationPage::testLogonAuthentication()
{
	return VigilCore::instance()->initAuthentication() &&
			VigilCore::platform().userFunctions().authenticate( VigilCore::authenticationCredentials().logonUsername(),
																VigilCore::authenticationCredentials().logonPassword() );
}



bool GeneralConfigurationPage::testKeyFileAuthentication()
{
	if( VigilCore::instance()->initAuthentication() == false )
	{
		QMessageBox::critical( this, authenticationTestTitle(),
							   tr( "Authentication keys are not set up properly on this computer." ) );
		return false;
	}

	return true;
}




void GeneralConfigurationPage::openLogFileDirectory()
{
	FileSystemBrowser(FileSystemBrowser::ExistingDirectory, this).exec(ui->logFileDirectory);
}




void GeneralConfigurationPage::clearLogFiles()
{
	bool serviceStopped = false;

	VigilServiceControl serviceControl( this );

	if( serviceControl.isServiceRunning() )
	{
		if (QMessageBox::question(this, tr("Vigil service"),
								   tr("The Vigil service needs to be stopped temporarily "
									  "in order to remove the log files. Continue?"),
								  QMessageBox::Yes | QMessageBox::No,
								  QMessageBox::Yes) == QMessageBox::Yes)
		{
			serviceControl.stopService();
			serviceStopped = true;
		}
		else
		{
			return;
		}
	}

	bool success = true;
	const QStringList logFilesFilter( { QStringLiteral("Vigil*.log") } );

	QDir d( VigilCore::filesystem().expandPath( VigilCore::config().logFileDirectory() ) );
	const auto localLogFiles = d.entryList( logFilesFilter );

	for( const auto& f : localLogFiles )
	{
		if( f.startsWith( QLatin1String("VigilConfigurator") ) )
		{
			d.remove( f );
		}
		else
		{
			success &= d.remove( f );
		}
	}

	d = QDir( VigilCore::platform().filesystemFunctions().globalTempPath() );
	const auto globalLogFiles = d.entryList( logFilesFilter );
	for( const auto& f : globalLogFiles )
	{
		if( f != QLatin1String("VigilConfigurator.log") )
		{
			success &= d.remove( f );
		}
	}

	if( serviceStopped )
	{
		serviceControl.startService();
	}

	if( success )
	{
		QMessageBox::information( this, tr( "Log files cleared" ),
								  tr( "All log files were cleared successfully." ) );
	}
	else
	{
		QMessageBox::critical( this, tr( "Error" ),
							   tr( "Could not remove all log files." ) );
	}
}



void GeneralConfigurationPage::populateNetworkObjectDirectories()
{
	const auto directories = VigilCore::networkObjectDirectoryManager().availableDirectories();

	for( auto it = directories.constBegin(), end = directories.constEnd(); it != end; ++it )
	{
		ui->networkObjectDirectoryPlugin->addItem( it.value(), it.key() );
	}
}
