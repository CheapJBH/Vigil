/*
 * VigilConnection.cpp - implementation of VigilConnection
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

#include "rfb/rfbclient.h"

#include "AuthenticationProxy.h"
#include "CryptoCore.h"
#include "PlatformUserFunctions.h"
#include "SocketDevice.h"
#include "VariantArrayMessage.h"
#include "VigilConfiguration.h"
#include "VigilConnection.h"
#include "VncFeatureMessageEvent.h"


static rfbClientProtocolExtension* __vigilProtocolExt = nullptr;
static const uint32_t __vigilSecurityTypes[2] = { rfbSecTypeVigil, 0 };


rfbBool handleVigilMessage( rfbClient* client, rfbServerToClientMsg* msg )
{
	auto connection = reinterpret_cast<VigilConnection *>( VncConnection::clientData( client, VigilConnection::VigilConnectionTag ) );
	if( connection )
	{
		return connection->handleServerMessage( client, msg->type ) ? TRUE : FALSE;
	}

	return FALSE;
}



VigilConnection::VigilConnection() :
	m_vigilAuthType(RfbVigilAuth::Logon)
{
	if( __vigilProtocolExt == nullptr )
	{
		__vigilProtocolExt = new rfbClientProtocolExtension;
		__vigilProtocolExt->encodings = nullptr;
		__vigilProtocolExt->handleEncoding = nullptr;
		__vigilProtocolExt->handleMessage = handleVigilMessage;
		__vigilProtocolExt->securityTypes = __vigilSecurityTypes;
		__vigilProtocolExt->handleAuthentication = handleSecTypeVigil;

		rfbClientRegisterExtension( __vigilProtocolExt );
	}

	if( VigilCore::config().authenticationMethod() == VigilCore::AuthenticationMethod::KeyFileAuthentication )
	{
		m_vigilAuthType = RfbVigilAuth::KeyFile;
	}

	connect( m_vncConnection, &VncConnection::connectionPrepared, this, &VigilConnection::registerConnection, Qt::DirectConnection );
	connect( m_vncConnection, &VncConnection::destroyed, VigilCore::instance(), [this]() {
		delete this;
	} );
}



VigilConnection::~VigilConnection()
{
	delete m_authenticationProxy;
}



void VigilConnection::stopAndDeleteLater()
{
	unregisterConnection();

	if( m_vncConnection )
	{
		m_vncConnection->stopAndDeleteLater();
		m_vncConnection = nullptr;
	}
}



void VigilConnection::sendFeatureMessage(const FeatureMessage& featureMessage)
{
	if( m_vncConnection )
	{
		m_vncConnection->enqueueEvent(new VncFeatureMessageEvent(featureMessage));
	}
}



bool VigilConnection::handleServerMessage( rfbClient* client, uint8_t msg )
{
	if( msg == FeatureMessage::RfbMessageType )
	{
		SocketDevice socketDev( VncConnection::libvncClientDispatcher, client );
		FeatureMessage featureMessage;
		if( featureMessage.receive( &socketDev ) == false )
		{
			vDebug() << "could not receive feature message";

			return false;
		}

		vDebug() << qUtf8Printable(QStringLiteral("%1:%2").arg(QString::fromUtf8(client->serverHost)).arg(client->serverPort))
				 << featureMessage;

		Q_EMIT featureMessageReceived( featureMessage );

		return true;
	}
	else
	{
		vCritical() << "unknown message type" << static_cast<int>( msg )
					<< "from server. Closing connection. Will re-open it later.";
	}

	return false;
}



void VigilConnection::registerConnection()
{
	if( m_vncConnection )
	{
		m_vncConnection->setClientData( VigilConnectionTag, this );
	}
}



void VigilConnection::unregisterConnection()
{
	if( m_vncConnection )
	{
		m_vncConnection->setClientData( VigilConnectionTag, nullptr );
	}
}



rfbBool VigilConnection::handleSecTypeVigil( rfbClient* client, uint32_t authScheme )
{
	if( authScheme != rfbSecTypeVigil )
	{
		return FALSE;
	}

	hookPrepareAuthentication( client );

	auto connection = static_cast<VigilConnection *>( VncConnection::clientData( client, VigilConnectionTag ) );
	if( connection == nullptr )
	{
		return FALSE;
	}

	const auto proxy = connection->m_authenticationProxy;

	SocketDevice socketDevice( VncConnection::libvncClientDispatcher, client );
	VariantArrayMessage message( &socketDevice );
	if( message.receive() == false )
	{
		vDebug() << QThread::currentThreadId() << "invalid authentication message received";
		if( proxy )
		{
			proxy->notifyProtocolError();
		}
		return FALSE;
	}

	const auto authTypeCount = message.read().toInt();

	if (authTypeCount == 0 || authTypeCount > 32)
	{
		vDebug() << QThread::currentThreadId() << "no or too many auth types received";
		if( proxy )
		{
			proxy->notifyProtocolError();
		}
		return FALSE;
	}

	QList<RfbVigilAuth::Type> authTypes;
	authTypes.reserve( authTypeCount );

	for( int i = 0; i < authTypeCount; ++i )
	{
		const auto authType = message.read().value<RfbVigilAuth::Type>();
		if( authType == RfbVigilAuth::Type::Invalid )
		{
			vDebug() << QThread::currentThreadId() << "invalid auth type received";
			if( proxy )
			{
				proxy->notifyProtocolError();
			}
			return FALSE;
		}
		authTypes.append( authType );
	}

	if( proxy )
	{
		proxy->setAuthenticationTypes( authTypes );
	}

	vDebug() << QThread::currentThreadId() << "received authentication types:" << authTypes;

	auto chosenAuthType = authTypes.first();
	if( proxy )
	{
		chosenAuthType = proxy->initCredentials();
	}
	// look whether the VncConnection recommends a specific authentication type (e.g. RfbVigilAuth::Token
	// when running as demo client)
	else if( authTypes.contains( connection->vigilAuthType() ) )
	{
		chosenAuthType = connection->vigilAuthType();
	}

	if( chosenAuthType == RfbVigilAuth::Invalid )
	{
		return FALSE;
	}

	vDebug() << QThread::currentThreadId() << "chose authentication type:" << authTypes;

	VariantArrayMessage authReplyMessage( &socketDevice );

	authReplyMessage.write( chosenAuthType );

	// send username which is used when displaying an access confirm dialog
	if( connection->authenticationCredentials().hasCredentials( AuthenticationCredentials::Type::UserLogon ) )
	{
		authReplyMessage.write( connection->authenticationCredentials().logonUsername() );
	}
	else
	{
		authReplyMessage.write(VigilCore::platform().userFunctions().queryCurrentUserProperty(PlatformUserFunctions::UserProperty::LoginName));
	}

	authReplyMessage.send();

	VariantArrayMessage authAckMessage( &socketDevice );
	if( authAckMessage.receive() == false )
	{
		vWarning() << QThread::currentThreadId() << "failed to receive authentication acknowledge";
		return FALSE;
	}

	switch( chosenAuthType )
	{
	case RfbVigilAuth::KeyFile:
		if( connection->authenticationCredentials().hasCredentials( AuthenticationCredentials::Type::PrivateKey ) )
		{
			VariantArrayMessage challengeReceiveMessage( &socketDevice );
			challengeReceiveMessage.receive();
			const auto challenge = challengeReceiveMessage.read().toByteArray();

			if( challenge.size() != CryptoCore::ChallengeSize )
			{
				vCritical() << QThread::currentThreadId() << "challenge size mismatch!";
				return FALSE;
			}

			// create local copy of private key so we can modify it within our own thread
			auto key = connection->authenticationCredentials().privateKey();
			if( key.isNull() || key.canSign() == false )
			{
				vCritical() << QThread::currentThreadId() << "invalid private key!";
				return FALSE;
			}

			const auto signature = key.signMessage( challenge, CryptoCore::DefaultSignatureAlgorithm );

			VariantArrayMessage challengeResponseMessage( &socketDevice );
			challengeResponseMessage.write( connection->authenticationCredentials().authenticationKeyName() );
			challengeResponseMessage.write( signature );
			challengeResponseMessage.send();
		}
		break;

	case RfbVigilAuth::Logon:
	{
		VariantArrayMessage publicKeyMessage( &socketDevice );
		publicKeyMessage.receive();

		CryptoCore::PublicKey publicKey = CryptoCore::PublicKey::fromPEM( publicKeyMessage.read().toString() );

		if( publicKey.canEncrypt() == false )
		{
			vCritical() << QThread::currentThreadId() << "can't encrypt with given public key!";
			return FALSE;
		}

		CryptoCore::SecureArray plainTextPassword( connection->authenticationCredentials().logonPassword() );
		CryptoCore::SecureArray encryptedPassword = publicKey.encrypt( plainTextPassword, CryptoCore::DefaultEncryptionAlgorithm );
		if( encryptedPassword.isEmpty() )
		{
			vCritical() << QThread::currentThreadId() << "password encryption failed!";
			return FALSE;
		}

		VariantArrayMessage passwordResponse( &socketDevice );
		passwordResponse.write( encryptedPassword.toByteArray() );
		passwordResponse.send();
		break;
	}

	case RfbVigilAuth::Token:
	{
		VariantArrayMessage tokenAuthMessage( &socketDevice );
		tokenAuthMessage.write( connection->authenticationCredentials().token().toByteArray() );
		tokenAuthMessage.send();
		break;
	}

	default:
		// nothing to do - we just get accepted
		break;
	}

	return TRUE;
}



void VigilConnection::hookPrepareAuthentication( rfbClient* client )
{
	auto connection = static_cast<VncConnection *>( VncConnection::clientData( client, VncConnection::VncConnectionTag ) );
	if( connection )
	{
		// set our internal flag which indicates that we basically have communication with the client
		// which means that the host is reachable
		connection->setServerReachable();
	}
}



AuthenticationCredentials VigilConnection::authenticationCredentials() const
{
	if( m_authenticationProxy )
	{
		return m_authenticationProxy->credentials();
	}

	return VigilCore::authenticationCredentials();
}
