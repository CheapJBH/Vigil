/*
 * ServiceControlCommands.cpp - implementation of ServiceControlCommands class
 *
 * Copyright (c) 2017-2026 Tobias Junghans <tobydox@vigil.io>
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

#include "CommandLineIO.h"
#include "ServiceControlCommands.h"
#include "VigilServiceControl.h"

ServiceControlCommands::ServiceControlCommands( QObject* parent ) :
	QObject( parent ),
	m_commands( {
{ QStringLiteral("register"), tr( "Register Vigil Service" ) },
{ QStringLiteral("unregister"), tr( "Unregister Vigil Service" ) },
{ QStringLiteral("start"), tr( "Start Vigil Service" ) },
{ QStringLiteral("stop"), tr( "Stop Vigil Service" ) },
{ QStringLiteral("restart"), tr( "Restart Vigil Service" ) },
{ QStringLiteral("status"), tr( "Query status of Vigil Service" ) },
				} )
{
}



CommandLinePluginInterface::RunResult ServiceControlCommands::handle_register( const QStringList& arguments )
{
	Q_UNUSED(arguments)

	VigilServiceControl serviceControl;
	serviceControl.registerService();

	return serviceControl.isServiceRegistered() ? Successful : Failed;
}



CommandLinePluginInterface::RunResult ServiceControlCommands::handle_unregister( const QStringList& arguments )
{
	Q_UNUSED(arguments)
	VigilServiceControl serviceControl;
	serviceControl.unregisterService();

	return serviceControl.isServiceRegistered() ? Failed : Successful;
}



CommandLinePluginInterface::RunResult ServiceControlCommands::handle_start( const QStringList& arguments )
{
	Q_UNUSED(arguments)

	VigilServiceControl serviceControl;
	serviceControl.startService();

	return serviceControl.isServiceRunning() ? Successful : Failed;
}



CommandLinePluginInterface::RunResult ServiceControlCommands::handle_stop( const QStringList& arguments )
{
	Q_UNUSED(arguments)

	VigilServiceControl serviceControl;
	serviceControl.stopService();

	return serviceControl.isServiceRunning() ? Failed : Successful;
}



CommandLinePluginInterface::RunResult ServiceControlCommands::handle_restart( const QStringList& arguments )
{
	handle_stop( arguments );
	return handle_start( arguments );
}



CommandLinePluginInterface::RunResult ServiceControlCommands::handle_status( const QStringList& arguments )
{
	Q_UNUSED(arguments)

	if( VigilServiceControl().isServiceRunning() )
	{
		CommandLineIO::print( tr( "Service is running" ) );
	}
	else
	{
		CommandLineIO::print( tr( "Service is not running" ) );
	}

	return NoResult;
}
