/*
 * VigilTitleBar.cpp - custom Windows 11 style title bar for Vigil
 *
 * Copyright (c) 2026 Vigil Solutions
 *
 * This file is part of Vigil - https://vigil.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 */

#include "VigilTitleBar.h"
#include "VigilWindowFrame.h"

#include <QEnterEvent>
#include <QHBoxLayout>
#include <QLabel>
#include <QMenu>
#include <QMouseEvent>
#include <QPainter>
#include <QToolButton>
#include <QWindow>

VigilTitleButton::VigilTitleButton( Kind kind, QWidget* parent ) :
	QAbstractButton( parent ),
	m_kind( kind )
{
	setFixedSize( 46, 32 );
	setCursor( Qt::ArrowCursor );
	setFocusPolicy( Qt::NoFocus );
	setAttribute( Qt::WA_Hover, true );
}


void VigilTitleButton::setKind( Kind kind )
{
	if( m_kind == kind )
	{
		return;
	}

	m_kind = kind;
	update();
}


void VigilTitleButton::paintEvent( QPaintEvent* event )
{
	Q_UNUSED( event )

	QPainter p( this );
	p.setRenderHint( QPainter::Antialiasing, true );

	const bool isClose = ( m_kind == Close );

	QColor background;
	if( m_hover )
	{
		background = isClose ? QColor( 0xC4, 0x2B, 0x1C ) : QColor( 0xEE, 0xF1, 0xF6 );
	}
	if( isDown() )
	{
		background = isClose ? QColor( 0xB0, 0x25, 0x18 ) : QColor( 0xE3, 0xE8, 0xEF );
	}

	if( background.isValid() )
	{
		p.setPen( Qt::NoPen );
		p.setBrush( background );
		p.drawRoundedRect( QRectF( rect() ).adjusted( 0, 4, 0, -4 ), 6, 6 );
	}

	QPen pen( ( m_hover && isClose ) ? QColor( Qt::white ) : QColor( 0x3A, 0x40, 0x4A ) );
	pen.setWidthF( 1.1 );
	pen.setCapStyle( Qt::FlatCap );
	p.setPen( pen );
	p.setBrush( Qt::NoBrush );

	const qreal cx = width() / 2.0;
	const qreal cy = height() / 2.0;
	const qreal s = 5.0;

	switch( m_kind )
	{
	case Minimize:
		p.drawLine( QPointF( cx - s, cy + 3 ), QPointF( cx + s, cy + 3 ) );
		break;

	case Maximize:
		p.drawRect( QRectF( cx - s, cy - s, s * 2, s * 2 ) );
		break;

	case Restore:
		p.drawRect( QRectF( cx - s, cy - s + 1.5, s * 2 - 1.5, s * 2 - 1.5 ) );
		p.drawLine( QPointF( cx - s + 1.5, cy - s + 0.5 ),
					QPointF( cx + s, cy - s + 0.5 ) );
		p.drawLine( QPointF( cx + s, cy - s + 0.5 ),
					QPointF( cx + s, cy + s - 2.5 ) );
		break;

	case Close:
		p.drawLine( QPointF( cx - s, cy - s ), QPointF( cx + s, cy + s ) );
		p.drawLine( QPointF( cx - s, cy + s ), QPointF( cx + s, cy - s ) );
		break;
	}
}


void VigilTitleButton::enterEvent( QEnterEvent* event )
{
	m_hover = true;
	update();
	QAbstractButton::enterEvent( event );
}


void VigilTitleButton::leaveEvent( QEvent* event )
{
	m_hover = false;
	update();
	QAbstractButton::leaveEvent( event );
}


VigilTitleBar::VigilTitleBar( QWidget* window, QWidget* parent ) :
	QWidget( parent ),
	m_window( window )
{
	setFixedHeight( 40 );
	setObjectName( QStringLiteral( "vigilTitleBar" ) );
	setSizePolicy( QSizePolicy::Expanding, QSizePolicy::Fixed );
	setAutoFillBackground( false );

	auto* layout = new QHBoxLayout( this );
	layout->setContentsMargins( 12, 0, 0, 0 );
	layout->setSpacing( 0 );

	m_iconLabel = new QLabel( this );
	m_iconLabel->setFixedSize( 18, 18 );
	m_iconLabel->setScaledContents( true );
	m_iconLabel->setObjectName( QStringLiteral( "vigilTitleIcon" ) );
	layout->addWidget( m_iconLabel );
	layout->addSpacing( 8 );

	m_titleLabel = new QLabel( this );
	m_titleLabel->setObjectName( QStringLiteral( "vigilTitleLabel" ) );
	layout->addWidget( m_titleLabel );
	layout->addSpacing( 14 );

	m_menuLayout = new QHBoxLayout;
	m_menuLayout->setContentsMargins( 0, 0, 0, 0 );
	m_menuLayout->setSpacing( 2 );
	layout->addLayout( m_menuLayout );

	layout->addStretch( 1 );

	m_minButton = new VigilTitleButton( VigilTitleButton::Minimize, this );
	m_maxButton = new VigilTitleButton( VigilTitleButton::Maximize, this );
	m_closeButton = new VigilTitleButton( VigilTitleButton::Close, this );

	layout->addWidget( m_minButton );
	layout->addWidget( m_maxButton );
	layout->addWidget( m_closeButton );

	if( m_window != nullptr )
	{
		QObject::connect( m_minButton, &QAbstractButton::clicked,
						  m_window, &QWidget::showMinimized );
		QObject::connect( m_maxButton, &QAbstractButton::clicked,
						  this, &VigilTitleBar::toggleMaximize );
		QObject::connect( m_closeButton, &QAbstractButton::clicked,
						  m_window, &QWidget::close );

		m_titleLabel->setText( m_window->windowTitle() );
		if( m_window->windowIcon().isNull() == false )
		{
			m_iconLabel->setPixmap( m_window->windowIcon().pixmap( 18, 18 ) );
		}
		else
		{
			m_iconLabel->hide();
		}

		m_window->installEventFilter( this );
		VigilWindowFrame::enable( m_window );

		updateMaximizeButton();
	}
}


void VigilTitleBar::setHeading( const QString& text )
{
	m_titleLabel->setText( text );
}


void VigilTitleBar::addMenu( QMenu* menu )
{
	if( menu == nullptr )
	{
		return;
	}

	auto* button = new QToolButton( this );
	button->setObjectName( QStringLiteral( "vigilTitleMenuButton" ) );
	button->setText( menu->title() );
	button->setMenu( menu );
	button->setPopupMode( QToolButton::InstantPopup );
	button->setToolButtonStyle( Qt::ToolButtonTextOnly );
	button->setFocusPolicy( Qt::NoFocus );
	button->setCursor( Qt::ArrowCursor );
	m_menuLayout->addWidget( button );
}


void VigilTitleBar::paintEvent( QPaintEvent* event )
{
	Q_UNUSED( event )

	QPainter p( this );
	p.fillRect( rect(), QColor( 0xFF, 0xFF, 0xFF ) );

	// 底部分隔线：1px 浅灰，和下方内容区区分开。
	p.setPen( QColor( 0xEC, 0xEF, 0xF4 ) );
	p.drawLine( 0, height() - 1, width() - 1, height() - 1 );
}


void VigilTitleBar::mousePressEvent( QMouseEvent* event )
{
	if( event->button() == Qt::LeftButton )
	{
		m_pressGlobalPos = event->globalPosition().toPoint();
		m_dragging = false;
		m_systemMoveStarted = false;

		if( m_window != nullptr )
		{
			m_dragOffset = m_pressGlobalPos - m_window->frameGeometry().topLeft();
		}
	}

	QWidget::mousePressEvent( event );
}


void VigilTitleBar::mouseMoveEvent( QMouseEvent* event )
{
	if( ( event->buttons() & Qt::LeftButton ) && m_window != nullptr && !m_systemMoveStarted )
	{
		const auto currentGlobal = event->globalPosition().toPoint();

		if( !m_dragging &&
			( currentGlobal - m_pressGlobalPos ).manhattanLength() > 4 )
		{
			m_dragging = true;

			// 优先交给系统处理：这样贴边吸附（Aero Snap）、
			// 多显示器、DPI 变化的行为都与原生标题栏一致。
			if( auto* handle = m_window->windowHandle() )
			{
				if( handle->startSystemMove() )
				{
					m_systemMoveStarted = true;
					return;
				}
			}
		}

		// 系统拖拽不可用时的回退方案。
		if( m_dragging && !m_systemMoveStarted )
		{
			m_window->move( currentGlobal - m_dragOffset );
		}
	}

	QWidget::mouseMoveEvent( event );
}


void VigilTitleBar::mouseReleaseEvent( QMouseEvent* event )
{
	m_dragging = false;
	m_systemMoveStarted = false;

	QWidget::mouseReleaseEvent( event );
}


void VigilTitleBar::mouseDoubleClickEvent( QMouseEvent* event )
{
	if( event->button() == Qt::LeftButton )
	{
		toggleMaximize();
		return;
	}

	QWidget::mouseDoubleClickEvent( event );
}


bool VigilTitleBar::eventFilter( QObject* watched, QEvent* event )
{
	if( watched == m_window )
	{
		switch( event->type() )
		{
		case QEvent::WindowTitleChange:
			m_titleLabel->setText( m_window->windowTitle() );
			break;

		case QEvent::WindowIconChange:
			if( m_window->windowIcon().isNull() == false )
			{
				m_iconLabel->setPixmap( m_window->windowIcon().pixmap( 18, 18 ) );
				m_iconLabel->show();
			}
			break;

		case QEvent::WindowStateChange:
			updateMaximizeButton();
			break;

		case QEvent::Show:
			VigilWindowFrame::enable( m_window );
			break;

		default:
			break;
		}
	}

	return QWidget::eventFilter( watched, event );
}


void VigilTitleBar::toggleMaximize()
{
	if( m_window == nullptr )
	{
		return;
	}

	if( m_window->isMaximized() )
	{
		m_window->showNormal();
	}
	else
	{
		m_window->showMaximized();
	}

	updateMaximizeButton();
}


void VigilTitleBar::updateMaximizeButton()
{
	if( m_window == nullptr || m_maxButton == nullptr )
	{
		return;
	}

	m_maxButton->setKind( m_window->isMaximized() ?
							  VigilTitleButton::Restore :
							  VigilTitleButton::Maximize );
}
