/*
 * VigilConfigurationProperties.h - definition of every configuration property
 *                                  stored in global vigil configuration
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
 * License along with this program (see COPYING) if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#pragma once

#include <QColor>
#include <QDir>
#include <QJsonArray>
#include <QJsonObject>

#include "ComputerListModel.h"
#include "Computer.h"
#include "Logger.h"
#include "MonitoringMode.h"
#include "NetworkObjectDirectory.h"
#include "PlatformSessionFunctions.h"
#include "PlatformUserFunctions.h"
#include "VncConnectionConfiguration.h"

#define FOREACH_VIGIL_CORE_CONFIG_PROPERTIES(OP)		\
	OP( VigilConfiguration, VigilCore::config(), VigilCore::ApplicationVersion, applicationVersion, setApplicationVersion, "ApplicationVersion", "Core", QVariant::fromValue(VigilCore::ApplicationVersion::Version_4_0), Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), QJsonObject, pluginVersions, setPluginVersions, "PluginVersions", "Core", QVariant(), Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), QString, installationID, setInstallationID, "InstallationID", "Core", QString(), Configuration::Property::Flag::Hidden )			\
	OP(VigilConfiguration, VigilCore::config(), int, computerStatePollingInterval, setComputerStatePollingInterval, "ComputerStatePollingInterval", "Core", -1, Configuration::Property::Flag::Hidden)	\

#define FOREACH_VIGIL_VNC_CONNECTION_CONFIG_PROPERTIES(OP)		\
	OP( VigilConfiguration, VigilCore::config(), bool, useCustomVncConnectionSettings, setUseCustomVncConnectionSettings, "UseCustomSettings", "VncConnection", false, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionThreadTerminationTimeout, setVncConnectionThreadTerminationTimeout, "ThreadTerminationTimeout", "VncConnection", VncConnectionConfiguration::DefaultThreadTerminationTimeout, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionConnectTimeout, setVncConnectionConnectTimeout, "ConnectTimeout", "VncConnection", VncConnectionConfiguration::DefaultConnectTimeout, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionReadTimeout, setVncConnectionReadTimeout, "ReadTimeout", "VncConnection", VncConnectionConfiguration::DefaultReadTimeout, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionRetryInterval, setVncConnectionRetryInterval, "ConnectionRetryInterval", "VncConnection", VncConnectionConfiguration::DefaultConnectionRetryInterval, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionMessageWaitTimeout, setVncConnectionMessageWaitTimeout, "MessageWaitTimeout", "VncConnection", VncConnectionConfiguration::DefaultMessageWaitTimeout, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionFastFramebufferUpdateInterval, setVncConnectionFastFramebufferUpdateInterval, "FastFramebufferUpdateInterval", "VncConnection", VncConnectionConfiguration::DefaultFastFramebufferUpdateInterval, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionInitialFramebufferUpdateTimeout, setVncConnectionInitialFramebufferUpdateTimeout, "InitialFramebufferUpdateTimeout", "VncConnection", VncConnectionConfiguration::DefaultInitialFramebufferUpdateTimeout, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionFramebufferUpdateTimeout, setVncConnectionFramebufferUpdateTimeout, "FramebufferUpdateTimeout", "VncConnection", VncConnectionConfiguration::DefaultFramebufferUpdateTimeout, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionSocketKeepaliveIdleTime, setVncConnectionSocketKeepaliveIdleTime, "SocketKeepaliveIdleTime", "VncConnection", VncConnectionConfiguration::DefaultSocketKeepaliveIdleTime, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionSocketKeepaliveInterval, setVncConnectionSocketKeepaliveInterval, "SocketKeepaliveInterval", "VncConnection", VncConnectionConfiguration::DefaultSocketKeepaliveInterval, Configuration::Property::Flag::Hidden )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncConnectionSocketKeepaliveCount, setVncConnectionSocketKeepaliveCount, "SocketKeepaliveCount", "VncConnection", VncConnectionConfiguration::DefaultSocketKeepaliveCount, Configuration::Property::Flag::Hidden )			\

#define FOREACH_VIGIL_UI_CONFIG_PROPERTY(OP)				\
	OP( VigilConfiguration, VigilCore::config(), QString, uiLanguage, setUiLanguage, "Language", "UI", QStringLiteral("System (zh_CN)"), Configuration::Property::Flag::Standard ) \
	OP( VigilConfiguration, VigilCore::config(), VigilCore::UiStyle, uiStyle, setUiStyle, "Style", "UI", QVariant::fromValue(VigilCore::UiStyle::Fusion), Configuration::Property::Flag::Standard ) \
	OP( VigilConfiguration, VigilCore::config(), VigilCore::UiColorScheme, uiColorScheme, setUiColorScheme, "ColorScheme", "UI", QVariant::fromValue(VigilCore::UiColorScheme::System), Configuration::Property::Flag::Standard )

#define FOREACH_VIGIL_SERVICE_CONFIG_PROPERTY(OP)				\
	OP( VigilConfiguration, VigilCore::config(), bool, isTrayIconHidden, setTrayIconHidden, "HideTrayIcon", "Service", false, Configuration::Property::Flag::Advanced )			\
	OP( VigilConfiguration, VigilCore::config(), bool, failedAuthenticationNotificationsEnabled, setFailedAuthenticationNotificationsEnabled, "FailedAuthenticationNotifications", "Service", true, Configuration::Property::Flag::Standard )			\
	OP( VigilConfiguration, VigilCore::config(), bool, remoteConnectionNotificationsEnabled, setRemoteConnectionNotificationsEnabled, "RemoteConnectionNotifications", "Service", false, Configuration::Property::Flag::Standard )			\
	OP( VigilConfiguration, VigilCore::config(), bool, activeSessionModeEnabled, setActiveSessionModeEnabled, "ActiveSession", "Service", false, Configuration::Property::Flag::Standard )			\
	OP( VigilConfiguration, VigilCore::config(), bool, multiSessionModeEnabled, setMultiSessionModeEnabled, "MultiSession", "Service", false, Configuration::Property::Flag::Standard )			\
	OP( VigilConfiguration, VigilCore::config(), int, maximumSessionCount, setMaximumSessionCount, "MaximumSessionCount", "Service", 100, Configuration::Property::Flag::Standard ) \
	OP( VigilConfiguration, VigilCore::config(), int, serverConnectionLimit, setServerConnectionLimit, "ServerConnectionLimit", "Service", 128, Configuration::Property::Flag::Advanced ) \
	OP( VigilConfiguration, VigilCore::config(), bool, autostartService, setServiceAutostart, "Autostart", "Service", true, Configuration::Property::Flag::Advanced )			\
	OP( VigilConfiguration, VigilCore::config(), bool, clipboardSynchronizationDisabled, setClipboardSynchronizationDisabled, "ClipboardSynchronizationDisabled", "Service", false, Configuration::Property::Flag::Advanced )					\
	OP( VigilConfiguration, VigilCore::config(), PlatformSessionFunctions::SessionMetaDataContent, sessionMetaDataContent, setSessionMetaDataContent, "SessionMetaDataContent", "Service", QVariant::fromValue(PlatformSessionFunctions::SessionMetaDataContent::None), Configuration::Property::Flag::Advanced )	\
	OP( VigilConfiguration, VigilCore::config(), QString, sessionMetaDataEnvironmentVariable, setSessionMetaDataEnvironmentVariable, "SessionMetaDataEnvironmentVariable", "Service", QString(), Configuration::Property::Flag::Advanced )	\
	OP( VigilConfiguration, VigilCore::config(), QString, sessionMetaDataRegistryKey, setSessionMetaDataRegistryKey, "SessionMetaDataRegistryKey", "Service", QString(), Configuration::Property::Flag::Advanced )	\

#define FOREACH_VIGIL_NETWORK_OBJECT_DIRECTORY_CONFIG_PROPERTY(OP)				\
	OP( VigilConfiguration, VigilCore::config(), QUuid, networkObjectDirectoryPlugin, setNetworkObjectDirectoryPlugin, "Plugin", "NetworkObjectDirectory", QUuid(), Configuration::Property::Flag::Standard )			\
	OP( VigilConfiguration, VigilCore::config(), int, networkObjectDirectoryUpdateInterval, setNetworkObjectDirectoryUpdateInterval, "UpdateInterval", "NetworkObjectDirectory", NetworkObjectDirectory::DefaultUpdateInterval, Configuration::Property::Flag::Standard )			\

#define FOREACH_VIGIL_USER_GROUPS_BACKEND_CONFIG_PROPERTY(OP)				\
	OP( VigilConfiguration, VigilCore::config(), QUuid, userGroupsBackend, setUserGroupsBackend, "Backend", "UserGroups", QUuid(), Configuration::Property::Flag::Standard )		\
	OP( VigilConfiguration, VigilCore::config(), bool, useDomainUserGroups, setUseDomainUserGroups, "UseDomainUserGroups", "UserGroups", false, Configuration::Property::Flag::Standard )		\

#define FOREACH_VIGIL_FEATURES_CONFIG_PROPERTY(OP)				\
	OP( VigilConfiguration, VigilCore::config(), QStringList, disabledFeatures, setDisabledFeatures, "DisabledFeatures", "Features", QStringList(), Configuration::Property::Flag::Standard )			\

#define FOREACH_VIGIL_LOGGING_CONFIG_PROPERTY(OP) \
	OP( VigilConfiguration, VigilCore::config(), Logger::LogLevel, logLevel, setLogLevel, "LogLevel", "Logging", QVariant::fromValue(Logger::LogLevel::Default), Configuration::Property::Flag::Standard )								\
	OP( VigilConfiguration, VigilCore::config(), bool, logFileSizeLimitEnabled, setLogFileSizeLimitEnabled, "LogFileSizeLimitEnabled", "Logging", false, Configuration::Property::Flag::Advanced )	\
	OP( VigilConfiguration, VigilCore::config(), bool, logFileRotationEnabled, setLogFileRotationEnabled, "LogFileRotationEnabled", "Logging", false, Configuration::Property::Flag::Advanced )	\
	OP( VigilConfiguration, VigilCore::config(), bool, logToStdErr, setLogToStdErr, "LogToStdErr", "Logging", true, Configuration::Property::Flag::Advanced )	\
	OP( VigilConfiguration, VigilCore::config(), bool, logToSystem, setLogToSystem, "LogToSystem", "Logging", false, Configuration::Property::Flag::Advanced )	\
	OP( VigilConfiguration, VigilCore::config(), int, logFileSizeLimit, setLogFileSizeLimit, "LogFileSizeLimit", "Logging", Logger::DefaultFileSizeLimit, Configuration::Property::Flag::Advanced )		\
	OP( VigilConfiguration, VigilCore::config(), int, logFileRotationCount, setLogFileRotationCount, "LogFileRotationCount", "Logging", Logger::DefaultFileRotationCount, Configuration::Property::Flag::Advanced )		\
	OP( VigilConfiguration, VigilCore::config(), QString, logFileDirectory, setLogFileDirectory, "LogFileDirectory", "Logging", QLatin1String(Logger::DefaultLogFileDirectory), Configuration::Property::Flag::Standard )		\

#define FOREACH_VIGIL_VNC_SERVER_CONFIG_PROPERTY(OP) \
	OP( VigilConfiguration, VigilCore::config(), QUuid, vncServerPlugin, setVncServerPlugin, "Plugin", "VncServer", QUuid(), Configuration::Property::Flag::Standard )	\

#define FOREACH_VIGIL_NETWORK_CONFIG_PROPERTY(OP) \
	OP( VigilConfiguration, VigilCore::config(), int, vigilServerPort, setVigilServerPort, "VigilServerPort", "Network", 11100, Configuration::Property::Flag::Advanced )			\
	OP( VigilConfiguration, VigilCore::config(), int, vncServerPort, setVncServerPort, "VncServerPort", "Network", 11200, Configuration::Property::Flag::Advanced )			\
	OP( VigilConfiguration, VigilCore::config(), int, featureWorkerManagerPort, setFeatureWorkerManagerPort, "FeatureWorkerManagerPort", "Network", 11300, Configuration::Property::Flag::Advanced )			\
	OP( VigilConfiguration, VigilCore::config(), int, demoServerPort, setDemoServerPort, "DemoServerPort", "Network", 11400, Configuration::Property::Flag::Advanced )			\
	OP( VigilConfiguration, VigilCore::config(), bool, isFirewallExceptionEnabled, setFirewallExceptionEnabled, "FirewallExceptionEnabled", "Network", true, Configuration::Property::Flag::Advanced )	\
	OP( VigilConfiguration, VigilCore::config(), bool, localConnectOnly, setLocalConnectOnly, "LocalConnectOnly", "Network", false, Configuration::Property::Flag::Advanced )					\

#define FOREACH_VIGIL_DIRECTORIES_CONFIG_PROPERTY(OP) \
	OP( VigilConfiguration, VigilCore::config(), QString, configurationTemplatesDirectory, setConfigurationTemplatesDirectory, "ConfigurationTemplates", "Directories", QDir::toNativeSeparators(QStringLiteral("%GLOBALAPPDATA%/Config/Templates")), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), QString, userConfigurationDirectory, setUserConfigurationDirectory, "UserConfiguration", "Directories", QDir::toNativeSeparators( QStringLiteral( "%APPDATA%/Config" ) ), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), QString, screenshotDirectory, setScreenshotDirectory, "Screenshots", "Directories", QDir::toNativeSeparators( QStringLiteral( "%APPDATA%/Screenshots" ) ), Configuration::Property::Flag::Standard )	\

#define FOREACH_VIGIL_MASTER_CONFIG_PROPERTY(OP) \
	OP( VigilConfiguration, VigilCore::config(), int, computerMonitoringUpdateInterval, setComputerMonitoringUpdateInterval, "ComputerMonitoringUpdateInterval", "Master", 1000, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), VncConnectionConfiguration::Quality, computerMonitoringImageQuality, setComputerMonitoringImageQuality, "ComputerMonitoringImageQuality", "Master", QVariant::fromValue(VncConnectionConfiguration::Quality::Medium), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), VncConnectionConfiguration::Quality, remoteAccessImageQuality, setRemoteAccessImageQuality, "RemoteAccessImageQuality", "Master", QVariant::fromValue(VncConnectionConfiguration::Quality::Highest), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), int, computerMonitoringThumbnailSpacing, setComputerMonitoringThumbnailSpacing, "ComputerMonitoringThumbnailSpacing", "Master", 5, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), ComputerListModel::DisplayRoleContent, computerDisplayRoleContent, setComputerDisplayRoleContent, "ComputerDisplayRoleContent", "Master", QVariant::fromValue(ComputerListModel::DisplayRoleContent::UserAndComputerName), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), ComputerListModel::UidRoleContent, computerUidRoleContent, setComputerUidRoleContent, "ComputerUidRoleContent", "Master", QVariant::fromValue(ComputerListModel::UidRoleContent::NetworkObjectUid), Configuration::Property::Flag::Advanced)	\
	OP( VigilConfiguration, VigilCore::config(), ComputerListModel::GridSizingMode, computerMonitoringGridSizingMode, setComputerMonitoringGridSizingMode, "ComputerMonitoringGridSizingMode", "Master", QVariant::fromValue(ComputerListModel::GridSizingMode::FullLengthLabels), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), ComputerListModel::VisibilityMode, computerMonitoringVisibilityMode, setComputerMonitoringVisibilityMode, "ComputerMonitoringVisibilityMode", "Master", QVariant::fromValue(ComputerListModel::VisibilityMode::Normal), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), ComputerListModel::SortOrder, computerMonitoringSortOrder, setComputerMonitoringSortOrder, "ComputerMonitoringSortOrder", "Master", QVariant::fromValue(ComputerListModel::SortOrder::ComputerAndUserName), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), ComputerListModel::AspectRatio, computerMonitoringAspectRatio, setComputerMonitoringAspectRatio, "ComputerMonitoringAspectRatio", "Master", QVariant::fromValue(ComputerListModel::AspectRatio::Auto), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), QColor, computerMonitoringBackgroundColor, setComputerMonitoringBackgroundColor, "ComputerMonitoringBackgroundColor", "Master", QColor(Qt::white), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), QColor, computerMonitoringTextColor, setComputerMonitoringTextColor, "ComputerMonitoringTextColor", "Master", QColor(Qt::black), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, accessControlForMasterEnabled, setAccessControlForMasterEnabled, "AccessControlForMasterEnabled", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, autoAdjustMonitoringIconSize, setAutoAdjustMonitoringIconSize, "AutoAdjustMonitoringIconSize", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, autoSelectCurrentLocation, setAutoSelectCurrentLocation, "AutoSelectCurrentLocation", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, showCurrentLocationOnly, setShowCurrentLocationOnly, "ShowCurrentLocationOnly", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, allowAddingHiddenLocations, setAllowAddingHiddenLocations, "AllowAddingHiddenLocations", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, expandLocations, setExpandLocations, "ExpandLocations", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, hideLocalComputer, setHideLocalComputer, "HideLocalComputer", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, hideOwnSession, setHideOwnSession, "HideOwnSession", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, hideEmptyLocations, setHideEmptyLocations, "HideEmptyLocations", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, hideComputerFilter, setHideComputerFilter, "HideComputerFilter", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), QUuid, computerDoubleClickFeature, setComputerDoubleClickFeature, "ComputerDoubleClickFeature", "Master", QUuid(QStringLiteral("a18e545b-1321-4d4e-ac34-adc421c6e9c8")), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, enforceSelectedModeForClients, setEnforceSelectedModeForClients, "EnforceSelectedModeForClients", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, autoOpenComputerSelectPanel, setAutoOpenComputerSelectPanel, "AutoOpenComputerSelectPanel", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, confirmUnsafeActions, setConfirmUnsafeActions, "ConfirmUnsafeActions", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), bool, showFeatureWindowsOnSameScreen, setShowFeatureWindowsOnSameScreen, "ShowFeatureWindowsOnSameScreen", "Master", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), Computer::NameSource, computerNameSource, setComputerNameSource, "ComputerNameSource", "Master", QVariant::fromValue(Computer::NameSource::Default), Configuration::Property::Flag::Advanced )	\
	OP( VigilConfiguration, VigilCore::config(), PlatformUserFunctions::UserProperty, guestUserProperty, setGuestUserProperty, "GuestUserProperty", "Master", QVariant::fromValue(PlatformUserFunctions::UserProperty::None), Configuration::Property::Flag::Advanced ) \
	OP( VigilConfiguration, VigilCore::config(), QString, guestUserValue, setGuestUserValue, "GuestUserValue", "Master", VigilCore::tr("Guest"), Configuration::Property::Flag::Advanced ) \
	OP( VigilConfiguration, VigilCore::config(), MonitoringMode::GuestUserIdentityExtensionType, guestUserIdentityExtensionType, setGuestUserIdentityExtensionType, "GuestUserIdentityExtensionType", "Master", QVariant::fromValue(MonitoringMode::GuestUserIdentityExtensionType::None), Configuration::Property::Flag::Advanced ) \
	OP( VigilConfiguration, VigilCore::config(), QString, guestUserIdentityExtensionValue, setGuestUserIdentityExtensionValue, "GuestUserIdentityExtensionValue", "Master", QString{}, Configuration::Property::Flag::Advanced ) \

#define FOREACH_VIGIL_AUTHENTICATION_CONFIG_PROPERTY(OP) \
	OP( VigilConfiguration, VigilCore::config(), VigilCore::AuthenticationMethod, authenticationMethod, setAuthenticationMethod, "Method", "Authentication", QVariant::fromValue(VigilCore::AuthenticationMethod::LogonAuthentication), Configuration::Property::Flag::Standard )	\

#define FOREACH_VIGIL_KEY_AUTHENTICATION_CONFIG_PROPERTY(OP) \
	OP( VigilConfiguration, VigilCore::config(), QString, privateKeyBaseDir, setPrivateKeyBaseDir, "PrivateKeyBaseDir", "Authentication", QDir::toNativeSeparators( QStringLiteral( "%GLOBALAPPDATA%/keys/private" ) ), Configuration::Property::Flag::Advanced )	\
	OP( VigilConfiguration, VigilCore::config(), QString, publicKeyBaseDir, setPublicKeyBaseDir, "PublicKeyBaseDir", "Authentication", QDir::toNativeSeparators( QStringLiteral( "%GLOBALAPPDATA%/keys/public" ) ), Configuration::Property::Flag::Advanced )	\

#define FOREACH_VIGIL_ACCESS_CONTROL_CONFIG_PROPERTY(OP)		\
	OP( VigilConfiguration, VigilCore::config(), bool, isAccessRestrictedToUserGroups, setAccessRestrictedToUserGroups, "AccessRestrictedToUserGroups", "AccessControl", false , Configuration::Property::Flag::Standard )		\
	OP( VigilConfiguration, VigilCore::config(), bool, isAccessControlRulesProcessingEnabled, setAccessControlRulesProcessingEnabled, "AccessControlRulesProcessingEnabled", "AccessControl", false, Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), QStringList, authorizedUserGroups, setAuthorizedUserGroups, "AuthorizedUserGroups", "AccessControl", QStringList(), Configuration::Property::Flag::Standard )	\
	OP( VigilConfiguration, VigilCore::config(), QJsonArray, accessControlRules, setAccessControlRules, "AccessControlRules", "AccessControl", QVariant(), Configuration::Property::Flag::Standard )	\

#define FOREACH_VIGIL_LEGACY_CONFIG_PROPERTY(OP) \
	OP( VigilConfiguration, VigilCore::config(), QUuid, legacyAccessControlUserGroupsBackend, setLegacyAccessControlUserGroupsBackend, "UserGroupsBackend", "AccessControl", QUuid(), Configuration::Property::Flag::Standard )		\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyDomainGroupsForAccessControlEnabled, setLegacyDomainGroupsForAccessControlEnabled, "DomainGroupsEnabled", "AccessControl", false, Configuration::Property::Flag::Standard )		\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyAutoAdjustGridSize, setLegacyAutoAdjustGridSize, "AutoAdjustGridSize", "Master", false, Configuration::Property::Flag::Legacy )	\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyOpenComputerManagementAtStart, setLegacyOpenComputerManagementAtStart, "OpenComputerManagementAtStart", "Master", false, Configuration::Property::Flag::Legacy )	\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyAutoSwitchToCurrentRoom, setLegacyAutoSwitchToCurrentRoom, "AutoSwitchToCurrentRoom", "Master", false, Configuration::Property::Flag::Legacy )	\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyOnlyCurrentRoomVisible, setLegacyOnlyCurrentRoomVisible, "OnlyCurrentRoomVisible", "Master", false, Configuration::Property::Flag::Legacy )	\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyManualRoomAdditionAllowed, setLegacyManualRoomAdditionAllowed, "ManualRoomAdditionAllowed", "Master", false, Configuration::Property::Flag::Legacy )	\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyEmptyRoomsHidden, setLegacyEmptyRoomsHidden, "EmptyRoomsHidden", "Master", false, Configuration::Property::Flag::Legacy )	\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyConfirmDangerousActions, setLegacyConfirmDangerousActions, "ConfirmDangerousActions", "Master", false, Configuration::Property::Flag::Legacy )	\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyIsSoftwareSASEnabled, setLegacySoftwareSASEnabled, "SoftwareSASEnabled", "Service", true, Configuration::Property::Flag::Legacy )			\
	OP( VigilConfiguration, VigilCore::config(), bool, legacyLocalComputerHidden, setLegacyLocalComputerHidden, "LocalComputerHidden", "Master", false, Configuration::Property::Flag::Legacy )       \
	OP( VigilConfiguration, VigilCore::config(), bool, legacyComputerFilterHidden, setLegacyComputerFilterHidden, "ComputerFilterHidden", "Master", false, Configuration::Property::Flag::Legacy )	\
	OP( VigilConfiguration, VigilCore::config(), int, legacyPrimaryServicePort, setLegacyPrimaryServicePort, "PrimaryServicePort", "Network", 11100, Configuration::Property::Flag::Legacy )			\

#define FOREACH_VIGIL_CONFIG_PROPERTY(OP)				\
	FOREACH_VIGIL_CORE_CONFIG_PROPERTIES(OP)			\
	FOREACH_VIGIL_VNC_CONNECTION_CONFIG_PROPERTIES(OP)	\
	FOREACH_VIGIL_UI_CONFIG_PROPERTY(OP)				\
	FOREACH_VIGIL_SERVICE_CONFIG_PROPERTY(OP)			\
	FOREACH_VIGIL_LOGGING_CONFIG_PROPERTY(OP)			\
	FOREACH_VIGIL_NETWORK_OBJECT_DIRECTORY_CONFIG_PROPERTY(OP)\
	FOREACH_VIGIL_USER_GROUPS_BACKEND_CONFIG_PROPERTY(OP)	\
	FOREACH_VIGIL_FEATURES_CONFIG_PROPERTY(OP)\
	FOREACH_VIGIL_VNC_SERVER_CONFIG_PROPERTY(OP)		\
	FOREACH_VIGIL_NETWORK_CONFIG_PROPERTY(OP)			\
	FOREACH_VIGIL_DIRECTORIES_CONFIG_PROPERTY(OP)	\
	FOREACH_VIGIL_MASTER_CONFIG_PROPERTY(OP)	\
	FOREACH_VIGIL_AUTHENTICATION_CONFIG_PROPERTY(OP)	\
	FOREACH_VIGIL_KEY_AUTHENTICATION_CONFIG_PROPERTY(OP)	\
	FOREACH_VIGIL_ACCESS_CONTROL_CONFIG_PROPERTY(OP) \
	FOREACH_VIGIL_LEGACY_CONFIG_PROPERTY(OP)
