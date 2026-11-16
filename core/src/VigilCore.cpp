/*
 * VigilCore.cpp - implementation of Vigil Core
 *
 * Copyright (c) 2006-2026 Tobias Junghans <tobydox@vigil.io>
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

#include <vigilconfig.h>

#include <QAbstractButton>
#include <QAction>
#include <QApplication>
#include <QDir>
#include <QFont>
#include <QGroupBox>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QLabel>
#include <QLibraryInfo>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QStyleFactory>
#include <QStyleHints>
#include <QSysInfo>
#include <QToolTip>

#include "BuiltinFeatures.h"
#include "FeatureManager.h"
#include "Filesystem.h"
#include "HostAddress.h"
#include "Logger.h"
#include "NetworkObjectDirectoryManager.h"
#include "PasswordDialog.h"
#include "PlatformPluginManager.h"
#include "PlatformCoreFunctions.h"
#include "PlatformSessionFunctions.h"
#include "PluginManager.h"
#include "TranslationLoader.h"
#include "UserGroupsBackendManager.h"
#include "VigilConfiguration.h"
#include "VncConnection.h"


VigilCore* VigilCore::s_instance = nullptr;


VigilCore::VigilCore( QCoreApplication* application, Component component, const QString& appComponentName ) :
	QObject( application ),
	m_filesystem( new Filesystem ),
	m_config( nullptr ),
	m_logger( nullptr ),
	m_authenticationCredentials( nullptr ),
	m_cryptoCore( nullptr ),
	m_pluginManager( nullptr ),
	m_platformPluginManager( nullptr ),
	m_platformPlugin( nullptr ),
	m_builtinFeatures( nullptr ),
	m_userGroupsBackendManager( nullptr ),
	m_networkObjectDirectoryManager( nullptr ),
	m_component( component ),
	m_debugging( false )
{
	Q_ASSERT( application != nullptr );

	s_instance = this;

	initPlatformPlugin();

	initConfiguration();

	initSession();

	initLogging( appComponentName );

	initLocaleAndTranslation();

	initUi();

	initCryptoCore();

	initAuthenticationCredentials();

	initPlugins();

	initManagers();

	initFeatures();

	initSystemInfo();

	Q_EMIT initialized(); // clazy:exclude=incorrect-emit
}



VigilCore::~VigilCore()
{
	vDebug();

	delete m_featureManager;
	m_featureManager = nullptr;

	delete m_builtinFeatures;
	m_builtinFeatures = nullptr;

	delete m_userGroupsBackendManager;
	m_userGroupsBackendManager = nullptr;

	delete m_authenticationCredentials;
	m_authenticationCredentials = nullptr;

	delete m_logger;
	m_logger = nullptr;

	delete m_platformPluginManager;
	m_platformPluginManager = nullptr;

	delete m_pluginManager;
	m_pluginManager = nullptr;

	delete m_config;
	m_config = nullptr;

	delete m_filesystem;
	m_filesystem = nullptr;

	delete m_cryptoCore;
	m_cryptoCore = nullptr;

	s_instance = nullptr;
}



VigilCore* VigilCore::instance()
{
	return s_instance;
}



QString VigilCore::versionString()
{
	return QStringLiteral( VIGIL_VERSION );
}



QString VigilCore::pluginDir()
{
	return QStringLiteral( VIGIL_PLUGIN_DIR );
}



QString VigilCore::translationsDirectory()
{
	return QCoreApplication::applicationDirPath() + QDir::separator() + QStringLiteral(VIGIL_TRANSLATIONS_DIR);
}



QString VigilCore::qtTranslationsDirectory()
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
	const auto path = QLibraryInfo::path(QLibraryInfo::TranslationsPath);
#else
	const auto path = QLibraryInfo::location(QLibraryInfo::TranslationsPath);
#endif
	if( QDir{path}.exists() )
	{
		return path;
	}

	return translationsDirectory();
}



QString VigilCore::executableSuffix()
{
	return QStringLiteral( VIGIL_EXECUTABLE_SUFFIX ); // clazy:exclude=empty-qstringliteral
}



QString VigilCore::sharedLibrarySuffix()
{
	return QStringLiteral( VIGIL_SHARED_LIBRARY_SUFFIX );
}



QString VigilCore::applicationsDirectory()
{
	return QStringLiteral(CMAKE_INSTALL_PREFIX "/share/applications");

}



QString VigilCore::sessionIdEnvironmentVariable()
{
	return QStringLiteral("VIGIL_SESSION_ID");
}



void VigilCore::setupApplicationParameters()
{
	QCoreApplication::setOrganizationName( QStringLiteral( "Vigil Solutions" ) );
	QCoreApplication::setOrganizationDomain( QStringLiteral( "vigil.io" ) );
	QCoreApplication::setApplicationName( QStringLiteral( "Vigil" ) );

	QCoreApplication::setAttribute( Qt::AA_ShareOpenGLContexts );

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
	QApplication::setAttribute( Qt::AA_UseHighDpiPixmaps );
#else
	// Windows 上 125% / 150% 缩放常见的非整数倍率：
	// 默认的 Round 策略会把界面放大到整数倍再缩小，导致字体和图标发虚，
	// PassThrough 让 Qt 按真实 DPR 渲染。
	QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
		Qt::HighDpiScaleFactorRoundingPolicy::PassThrough );
#endif

#ifdef Q_OS_WIN
	// 中文界面在 Windows 上默认回退到宋体，与系统 UI 的雅黑不一致且发虚，
	// 这里只登记字体替换，不改变字号与字重。
	QFont::insertSubstitution( QStringLiteral("Segoe UI"),
							   QStringLiteral("Microsoft YaHei UI") );
	QFont::insertSubstitution( QStringLiteral("MS Shell Dlg 2"),
							   QStringLiteral("Microsoft YaHei UI") );
#endif
}



bool VigilCore::initAuthentication()
{
	switch( config().authenticationMethod() )
	{
	case AuthenticationMethod::LogonAuthentication: return initLogonAuthentication();
	case AuthenticationMethod::KeyFileAuthentication: return initKeyFileAuthentication();
	}

	return false;
}



bool VigilCore::useDarkMode()
{
	const auto colorScheme = config().uiColorScheme();

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
	if (colorScheme == UiColorScheme::System &&
		QGuiApplication::styleHints() &&
		QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark)
	{
		return true;
	}
#endif

	if (colorScheme == UiColorScheme::Dark)
	{
		return true;
	}

	return false;
}



bool VigilCore::isDebugging()
{
	return s_instance && s_instance->m_debugging;
}



QByteArray VigilCore::shortenFuncinfo( const QByteArray& info )
{
	const auto funcinfo = cleanupFuncinfo( info );

	if( isDebugging() )
	{
		return funcinfo + QByteArrayLiteral( "():" );
	}

	return funcinfo.split( ':' ).first() + QByteArrayLiteral(":");
}



// taken from qtbase/src/corelib/global/qlogging.cpp

QByteArray VigilCore::cleanupFuncinfo( QByteArray info )
{
	// Strip the function info down to the base function name
	// note that this throws away the template definitions,
	// the parameter types (overloads) and any const/volatile qualifiers.

	if (info.isEmpty())
		return info;

	int pos;

	// Skip trailing [with XXX] for templates (gcc), but make
	// sure to not affect Objective-C message names.
	pos = info.size() - 1;
	if (info.endsWith(']') && !(info.startsWith('+') || info.startsWith('-'))) {
		while (--pos) {
			if (info.at(pos) == '[')
				info.truncate(pos);
		}
	}

	// operator names with '(', ')', '<', '>' in it
	static const char operator_call[] = "operator()";
	static const char operator_lessThan[] = "operator<";
	static const char operator_greaterThan[] = "operator>";
	static const char operator_lessThanEqual[] = "operator<=";
	static const char operator_greaterThanEqual[] = "operator>=";

	// canonize operator names
	info.replace("operator ", "operator");

	// remove argument list
	Q_FOREVER {
		int parencount = 0;
		pos = info.lastIndexOf(')');
		if (pos == -1) {
			// Don't know how to parse this function name
			return info;
		}

		// find the beginning of the argument list
		--pos;
		++parencount;
		while (pos && parencount) {
			if (info.at(pos) == ')')
				++parencount;
			else if (info.at(pos) == '(')
				--parencount;
			--pos;
		}
		if (parencount != 0)
			return info;

		info.truncate(++pos);

		if (info.at(pos - 1) == ')') {
			if (info.indexOf(operator_call) == pos - (int)strlen(operator_call))
				break;

			// this function returns a pointer to a function
			// and we matched the arguments of the return type's parameter list
			// try again
			info.remove(0, info.indexOf('('));
			info.chop(1);
			continue;
		} else {
			break;
		}
	}

	// find the beginning of the function name
	int parencount = 0;
	int templatecount = 0;
	--pos;

	// make sure special characters in operator names are kept
	if (pos > -1) {
		switch (info.at(pos)) {
		case ')':
			if (info.indexOf(operator_call) == pos - (int)strlen(operator_call) + 1)
				pos -= 2;
			break;
		case '<':
			if (info.indexOf(operator_lessThan) == pos - (int)strlen(operator_lessThan) + 1)
				--pos;
			break;
		case '>':
			if (info.indexOf(operator_greaterThan) == pos - (int)strlen(operator_greaterThan) + 1)
				--pos;
			break;
		case '=': {
			int operatorLength = (int)strlen(operator_lessThanEqual);
			if (info.indexOf(operator_lessThanEqual) == pos - operatorLength + 1)
				pos -= 2;
			else if (info.indexOf(operator_greaterThanEqual) == pos - operatorLength + 1)
				pos -= 2;
			break;
		}
		default:
			break;
		}
	}

	while (pos > -1) {
		if (parencount < 0 || templatecount < 0)
			return info;

		char c = info.at(pos);
		if (c == ')')
			++parencount;
		else if (c == '(')
			--parencount;
		else if (c == '>')
			++templatecount;
		else if (c == '<')
			--templatecount;
		else if (c == ' ' && templatecount == 0 && parencount == 0)
			break;

		--pos;
	}
	info = info.mid(pos + 1);

	// remove trailing '*', '&' that are part of the return argument
	while ((info.at(0) == '*')
		   || (info.at(0) == '&'))
		info = info.mid(1);

	// we have the full function name now.
	// clean up the templates
	while ((pos = info.lastIndexOf('>')) != -1) {
		if (!info.contains('<'))
			break;

		// find the matching close
		int end = pos;
		templatecount = 1;
		--pos;
		while (pos && templatecount) {
			char c = info.at(pos);
			if (c == '>')
				++templatecount;
			else if (c == '<')
				--templatecount;
			--pos;
		}
		++pos;
		info.remove(pos, end - pos + 1);
	}

	return info;
}



QString VigilCore::stripDomain( const QString& username )
{
	// remove the domain part of username (e.g. "EXAMPLE.COM\Teacher" -> "Teacher")
	int domainSeparator = username.indexOf( QLatin1Char('\\') );
	if( domainSeparator >= 0 )
	{
		return username.mid( domainSeparator + 1 );
	}

	return username;
}



QString VigilCore::stringify( const QVariantMap& map )
{
	return QString::fromUtf8( QJsonDocument(QJsonObject::fromVariantMap(map)).toJson(QJsonDocument::Compact) );
}



QString VigilCore::screenName(const QScreen& screen, int index)
{
	auto screenName = tr("Screen %1").arg(index);

	const auto displayDeviceName = platform().coreFunctions().queryDisplayDeviceName(screen);
	if(displayDeviceName.isEmpty() == false)
	{
		screenName.append(QStringLiteral(" – %1").arg(displayDeviceName));
	}

	return screenName;
}



bool VigilCore::isAuthenticationKeyNameValid( const QString& authKeyName )
{
	static const QRegularExpression keyNameRX{QStringLiteral("^[\\w-]+$")};
	return keyNameRX.match( authKeyName ).hasMatch();
}



int VigilCore::exec()
{
	Q_EMIT applicationLoaded();

	vDebug() << "Running";

	const auto result = QCoreApplication::instance()->exec();

	vDebug() << "Exit";

	Q_EMIT exited();

	return result;
}



void VigilCore::initPlatformPlugin()
{
	// initialize plugin manager and load platform plugins first
	m_pluginManager = new PluginManager( this );
	m_pluginManager->loadPlatformPlugins();

	// initialize platform plugin manager and initialize used platform plugin
	m_platformPluginManager = new PlatformPluginManager( *m_pluginManager );
	m_platformPlugin = m_platformPluginManager->platformPlugin();
}



void VigilCore::initSession()
{
	if( component() != Component::Service && config().multiSessionModeEnabled() )
	{
		const auto systemEnv = QProcessEnvironment::systemEnvironment();
		if( systemEnv.contains( sessionIdEnvironmentVariable() ) )
		{
			m_sessionId = systemEnv.value( sessionIdEnvironmentVariable() ).toInt();
		}
		else
		{
			const auto sessionId = platform().sessionFunctions().currentSessionId();
			if( sessionId != PlatformSessionFunctions::InvalidSessionId )
			{
				m_sessionId = sessionId;
			}
		}
	}
	else
	{
		m_sessionId = PlatformSessionFunctions::DefaultSessionId;
	}
}


void VigilCore::initConfiguration()
{
	m_config = new VigilConfiguration();
	m_config->upgrade();

	if( QUuid( config().installationID() ).isNull() )
	{
		config().setInstallationID(QUuid::createUuid().toString(QUuid::WithoutBraces));
	}
}



void VigilCore::initLogging( const QString& appComponentName )
{
	const auto currentSessionId = sessionId();

	if( currentSessionId != PlatformSessionFunctions::DefaultSessionId )
	{
		m_logger = new Logger( QStringLiteral("%1-%2").arg( appComponentName ).arg( currentSessionId ) );
	}
	else
	{
		m_logger = new Logger( appComponentName );
	}

	m_debugging = ( m_logger->logLevel() >= Logger::LogLevel::Debug );

	VncConnection::initLogging( isDebugging() );
}



void VigilCore::initLocaleAndTranslation()
{
	if( TranslationLoader::load( QStringLiteral("qtbase") ) == false )
	{
		TranslationLoader::load( QStringLiteral("qt") );
	}

	TranslationLoader::load( QStringLiteral("vigil") );

	const auto app = qobject_cast<QGuiApplication *>( QCoreApplication::instance() );
	if( app )
	{
		QGuiApplication::setLayoutDirection( QLocale{}.textDirection() );
	}
}



void VigilCore::initUi()
{
	auto app = qobject_cast<QApplication *>(QCoreApplication::instance());
	if (app)
	{
		if (m_config->uiStyle() == UiStyle::Fusion)
		{
			app->setStyle(QStyleFactory::create(QStringLiteral("Fusion")));
		}

		app->setStyleSheet(QStringLiteral(
							   "QToolButton:checked {background-color:#88ddff;}"
							   "QToolTip {padding:5px; border:0px;}"
							   ));

		auto toolTipPalette = QToolTip::palette();
		static const char* toolTipBackgroundColor = "#198cb3";
		toolTipPalette.setColor(QPalette::Window, toolTipBackgroundColor);
		toolTipPalette.setColor(QPalette::ToolTipBase, toolTipBackgroundColor);
		toolTipPalette.setColor(QPalette::ToolTipText, Qt::white);
		QToolTip::setPalette(toolTipPalette);

#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
		switch (config().uiColorScheme())
		{
		case UiColorScheme::Dark:
			QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Dark);
			break;
		case UiColorScheme::Light:
			QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Light);
			break;
		default:
			break;
		}
#endif
	}
}



void VigilCore::initCryptoCore()
{
	m_cryptoCore = new CryptoCore;
}



void VigilCore::initAuthenticationCredentials()
{
	if( m_authenticationCredentials )
	{
		delete m_authenticationCredentials;
		m_authenticationCredentials = nullptr;
	}

	m_authenticationCredentials = new AuthenticationCredentials;
}



void VigilCore::initPlugins()
{
	// load all other (non-platform) plugins
	m_pluginManager->loadPlugins();
	m_pluginManager->upgradePlugins();
}



void VigilCore::initManagers()
{
	m_userGroupsBackendManager = new UserGroupsBackendManager( this );
	m_networkObjectDirectoryManager = new NetworkObjectDirectoryManager( this );
}



void VigilCore::initFeatures()
{
	m_builtinFeatures = new BuiltinFeatures();
	m_featureManager = new FeatureManager(this);
}



bool VigilCore::initLogonAuthentication()
{
	if( qobject_cast<QApplication *>( QCoreApplication::instance() ) )
	{
		PasswordDialog dlg( QApplication::activeWindow() );
		if( dlg.exec() &&
			dlg.credentials().hasCredentials( AuthenticationCredentials::Type::UserLogon ) )
		{
			m_authenticationCredentials->setLogonUsername( dlg.username() );
			m_authenticationCredentials->setLogonPassword( dlg.password() );

			return true;
		}
	}

	return false;
}



bool VigilCore::initKeyFileAuthentication()
{
	auto authKeyName = QProcessEnvironment::systemEnvironment().value( QStringLiteral("VIGIL_AUTH_KEY_NAME") );

	if( authKeyName.isEmpty() == false )
	{
		if( isAuthenticationKeyNameValid( authKeyName ) &&
				m_authenticationCredentials->loadPrivateKey( VigilCore::filesystem().privateKeyPath( authKeyName ) ) )
		{
			m_authenticationCredentials->setAuthenticationKeyName( authKeyName );
			return true;
		}
	}
	else
	{
		// try to auto-detect private key file by searching for readable file
		const auto privateKeyBaseDir = VigilCore::filesystem().expandPath( VigilCore::config().privateKeyBaseDir() );
		const auto privateKeyDirs = QDir( privateKeyBaseDir ).entryList( QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name );

		for( const auto& privateKeyDir : privateKeyDirs )
		{
			if( m_authenticationCredentials->loadPrivateKey( VigilCore::filesystem().privateKeyPath( privateKeyDir ) ) )
			{
				m_authenticationCredentials->setAuthenticationKeyName( privateKeyDir );
				return true;
			}
		}
	}

	return false;
}



void VigilCore::initSystemInfo()
{
	vDebug() << versionString() << HostAddress::localFQDN()
			 << QSysInfo::kernelType() << QSysInfo::kernelVersion()
			 << QSysInfo::prettyProductName() << QSysInfo::productType() << QSysInfo::productVersion();
}
