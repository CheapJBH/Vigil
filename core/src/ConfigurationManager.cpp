/*
 * ConfigurationManager.cpp - class for managing Vigil's configuration
 *
 * Copyright (c) 2010-2026 Tobias Junghans <tobydox@vigil.io>
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

#include "Configuration/LocalStore.h"
#include "ConfigurationManager.h"
#include "Filesystem.h"
#include "Logger.h"
#include "PlatformCoreFunctions.h"
#include "PlatformNetworkFunctions.h"
#include "VigilConfiguration.h"
#include "VigilServiceControl.h"



ConfigurationManager::ConfigurationManager( QObject* parent ) :
	QObject( parent ),
	m_configuration( VigilCore::config() )
{
}



bool ConfigurationManager::clearConfiguration()
{
	Configuration::LocalStore(Configuration::LocalStore::Scope::System).clear();

	return true;
}



bool ConfigurationManager::applyConfiguration()
{
	// 防杀保护会移除服务的 SERVICE_CHANGE_CONFIG 权限，此时修改自启动
	// 属性必然失败。配置本身仍然要保存下来，所以这里只记录警告，
	// 不再让整个应用流程失败。
	if( VigilServiceControl().setAutostart( m_configuration.autostartService() ) == false )
	{
		vWarning() << "Could not modify the autostart property for the Vigil Service"
					  " (service protection is probably active)";
	}

	auto& network = VigilCore::platform().networkFunctions();

	if( network.configureFirewallException( VigilCore::filesystem().serverFilePath(),
											QStringLiteral("Vigil Server"),
											m_configuration.isFirewallExceptionEnabled() ) == false )
	{
		m_errorString = tr("Could not configure the firewall configuration for the Vigil Server.");
		return false;
	}

	if( network.configureFirewallException( VigilCore::filesystem().workerFilePath(),
											QStringLiteral("Vigil Worker"),
											m_configuration.isFirewallExceptionEnabled() ) == false )
	{
		m_errorString = tr("Could not configure the firewall configuration for the Vigil Worker.");
		return false;
	}

	if( VigilCore::platform().coreFunctions().applyConfiguration() == false )
	{
		m_errorString =  tr("Could not apply platform-specific configuration settings.");
		return false;
	}

	return true;
}



bool ConfigurationManager::saveConfiguration()
{
	// write global configuration
	Configuration::LocalStore localStore(Configuration::LocalStore::Scope::System);
	if( localStore.isWritable() == false )
	{
		m_errorString = tr( "Configuration is not writable. Please check your permissions!" );
		return false;
	}

	localStore.flush( &m_configuration );
	return true;
}
