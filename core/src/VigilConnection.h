/*
 * VigilConnection.h - declaration of class VigilConnection
 *
 * Copyright (c) 2008-2026 Tobias Junghans <tobydox@vigil.io>
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

#include <QPointer>

#include "RfbVigilAuth.h"
#include "VncConnection.h"

class AuthenticationProxy;
class FeatureMessage;

class VIGIL_CORE_EXPORT VigilConnection : public QObject
{
	Q_OBJECT
public:
	using Instances = struct {
		QMutex mutex;
		QHash<QThread *, VigilConnection *> connections;
	};

	VigilConnection();

	void stopAndDeleteLater();

	VncConnection* vncConnection()
	{
		return m_vncConnection;
	}

	VncConnection::State state() const
	{
		return m_vncConnection->state();
	}

	bool isConnected() const
	{
		return m_vncConnection && m_vncConnection->isConnected();
	}

	void setVigilAuthType( RfbVigilAuth::Type authType )
	{
		m_vigilAuthType = authType;
	}

	RfbVigilAuth::Type vigilAuthType() const
	{
		return m_vigilAuthType;
	}

	void setAuthenticationProxy( AuthenticationProxy* authenticationProxy )
	{
		m_authenticationProxy = authenticationProxy;
	}

	void sendFeatureMessage(const FeatureMessage& featureMessage);

	bool handleServerMessage( rfbClient* client, uint8_t msg );

	static constexpr auto VigilConnectionTag = 0xFE14A11;


Q_SIGNALS:
	void featureMessageReceived( const FeatureMessage& );

private:
	~VigilConnection() override;

	void registerConnection();
	void unregisterConnection();

	// authentication
	static int8_t handleSecTypeVigil( rfbClient* client, uint32_t authScheme );
	static void hookPrepareAuthentication( rfbClient* client );

	AuthenticationCredentials authenticationCredentials() const;

	VncConnection* m_vncConnection{new VncConnection};

	RfbVigilAuth::Type m_vigilAuthType;

	AuthenticationProxy* m_authenticationProxy{nullptr};
	QString m_accessControlMessage;

} ;
