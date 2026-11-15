/*
 * FeatureManager.h - header for the FeatureManager class
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

#include <QObject>

#include "Feature.h"
#include "FeatureProviderInterface.h"
#include "ComputerControlInterface.h"
#include "Plugin.h"

class QWidget;

class FeatureWorkerManager;

class VIGIL_CORE_EXPORT FeatureManager : public QObject
{
	Q_OBJECT
public:
	explicit FeatureManager( QObject* parent = nullptr );

	const FeatureList& features() const
	{
		return m_features;
	}

	const FeatureList& features( Plugin::Uid pluginUid ) const;

	const Feature& feature( Feature::Uid featureUid ) const;

	const FeatureList& relatedFeatures( Feature::Uid featureUid ) const;

	Feature::Uid metaFeatureUid( Feature::Uid featureUid ) const;

	Plugin::Uid pluginUid( Feature::Uid featureUid ) const;


	void controlFeature( Feature::Uid featureUid,
						FeatureProviderInterface::Operation operation,
						const QVariantMap& arguments,
						const ComputerControlInterfaceList& computerControlInterfaces ) const;

	void startFeature( VigilMasterInterface& master,
					   const Feature& feature,
					   const ComputerControlInterfaceList& computerControlInterfaces ) const;
	void stopFeature( VigilMasterInterface& master,
					  const Feature& feature,
					  const ComputerControlInterfaceList& computerControlInterfaces ) const;

	void handleFeatureMessage(ComputerControlInterface::Pointer computerControlInterface,
							  const FeatureMessage& message) const;
	void handleFeatureMessage(VigilServerInterface& server,
							  const MessageContext& messageContext,
							  const FeatureMessage& message) const;
	void handleFeatureMessageFromWorker(VigilServerInterface& server,
										const FeatureMessage& message) const;
	void handleFeatureMessage(VigilWorkerInterface& worker, const FeatureMessage& message) const;

	void sendAsyncFeatureMessages(VigilServerInterface& server, const MessageContext& messageContext) const;

	FeatureUidList activeFeatures( VigilServerInterface& server ) const;

private:
	FeatureList m_features;
	FeatureUidList m_disabledFeaturesUids{};
	const FeatureList m_emptyFeatureList;
	QObjectList m_pluginObjects;
	FeatureProviderInterfaceList m_featurePluginInterfaces;
	const Feature m_dummyFeature;

};
