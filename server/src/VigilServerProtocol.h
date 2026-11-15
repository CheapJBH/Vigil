/*
 * VigilServerProtocol.h - header file for the VigilServerProtocol class
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

#pragma once

#include "VncServerProtocol.h"

class QTcpSocket;

class ServerAuthenticationManager;
class ServerAccessControlManager;

// clazy:excludeall=copyable-polymorphic

class VigilServerProtocol : public VncServerProtocol
{
public:
	VigilServerProtocol( QTcpSocket* socket,
						  VncServerClient* client,
						  ServerAuthenticationManager& serverAuthenticationManager,
						  ServerAccessControlManager& serverAccessControlManager );

protected:
	QVector<RfbVigilAuth::Type> supportedAuthTypes() const override;
	void processAuthenticationMessage( VariantArrayMessage& message ) override;
	void performAccessControl() override;

private:
	ServerAuthenticationManager& m_serverAuthenticationManager;
	ServerAccessControlManager& m_serverAccessControlManager;

} ;
