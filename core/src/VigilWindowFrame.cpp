/*
 * VigilWindowFrame.cpp - frameless window helper for Vigil
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

#include "VigilWindowFrame.h"

#include <QAbstractNativeEventFilter>
#include <QApplication>
#include <QEvent>
#include <QWidget>

#ifdef Q_OS_WIN
#include <windows.h>
#include <windowsx.h>
#include <dwmapi.h>

// 这些常量在较老的 MinGW 头文件里可能缺失，按微软文档手工补齐。
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWCP_DEFAULT
#define DWMWCP_DEFAULT 0
#endif
#ifndef DWMWCP_DONOTROUND
#define DWMWCP_DONOTROUND 1
#endif
#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif
#ifndef DWMWCP_ROUNDSMALL
#define DWMWCP_ROUNDSMALL 3
#endif
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#endif

namespace
{

#ifdef Q_OS_WIN

class VigilNativeEventFilter : public QAbstractNativeEventFilter
{
public:
	explicit VigilNativeEventFilter( VigilWindowFrame* owner ) :
		m_owner( owner )
	{
	}

#if QT_VERSION >= QT_VERSION_CHECK( 6, 0, 0 )
	bool nativeEventFilter( const QByteArray& eventType, void* message, qintptr* result ) override
#else
	bool nativeEventFilter( const QByteArray& eventType, void* message, long* result ) override
#endif
	{
		if( eventType != QByteArrayLiteral( "windows_generic_MSG" ) )
		{
			return false;
		}

		auto* msg = static_cast<MSG*>( message );
		if( msg == nullptr || m_owner->handlesWindow( WId( msg->hwnd ) ) == false )
		{
			return false;
		}

		switch( msg->message )
		{
		case WM_NCCALCSIZE:
			// 去系统标题栏：客户区直接铺满整个窗口。
			if( msg->wParam == FALSE )
			{
				return false;
			}
			{
				auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>( msg->lParam );
				if( params == nullptr )
				{
					return false;
				}

				// 最大化时把客户区压回显示器工作区，否则 Qt 内容会被
				// 算到屏幕外，右侧和底部按钮被裁掉。
				if( IsZoomed( msg->hwnd ) )
				{
					MONITORINFO mi {};
					mi.cbSize = sizeof( mi );
					if( GetMonitorInfoW( MonitorFromWindow( msg->hwnd, MONITOR_DEFAULTTONEAREST ), &mi ) )
					{
						params->rgrc[0] = mi.rcWork;
					}
				}

				*result = 0;
				return true;
			}

		case WM_NCHITTEST:
			{
				if( IsZoomed( msg->hwnd ) )
				{
					return false;
				}

				POINT pt {};
				pt.x = GET_X_LPARAM( msg->lParam );
				pt.y = GET_Y_LPARAM( msg->lParam );

				RECT rc {};
				if( GetWindowRect( msg->hwnd, &rc ) == FALSE )
				{
					return false;
				}

				// 贴边缩放的判定宽度（逻辑像素）。
				const int border = 6;
				const bool left = pt.x >= rc.left && pt.x < rc.left + border;
				const bool right = pt.x <= rc.right && pt.x > rc.right - border;
				const bool top = pt.y >= rc.top && pt.y < rc.top + border;
				const bool bottom = pt.y <= rc.bottom && pt.y > rc.bottom - border;

				if( top && left )      { *result = HTTOPLEFT; return true; }
				if( top && right )     { *result = HTTOPRIGHT; return true; }
				if( bottom && left )   { *result = HTBOTTOMLEFT; return true; }
				if( bottom && right )  { *result = HTBOTTOMRIGHT; return true; }
				if( left )             { *result = HTLEFT; return true; }
				if( right )            { *result = HTRIGHT; return true; }
				if( top )              { *result = HTTOP; return true; }
				if( bottom )           { *result = HTBOTTOM; return true; }
			}
			return false;

		default:
			break;
		}

		return false;
	}

private:
	VigilWindowFrame* m_owner;
};

#endif // Q_OS_WIN

} // namespace


VigilWindowFrame::VigilWindowFrame() :
	QObject( nullptr )
{
}


VigilWindowFrame::~VigilWindowFrame()
{
#ifdef Q_OS_WIN
	if( m_nativeFilter != nullptr && qApp != nullptr )
	{
		qApp->removeNativeEventFilter( m_nativeFilter );
	}
	delete m_nativeFilter;
#endif
}


VigilWindowFrame* VigilWindowFrame::instance()
{
	static VigilWindowFrame* s_instance = nullptr;
	if( s_instance == nullptr )
	{
		s_instance = new VigilWindowFrame;
#ifdef Q_OS_WIN
		if( qApp != nullptr )
		{
			s_instance->m_nativeFilter = new VigilNativeEventFilter( s_instance );
			qApp->installNativeEventFilter( s_instance->m_nativeFilter );
		}
#endif
	}

	return s_instance;
}


void VigilWindowFrame::enable( QWidget* window )
{
	if( window == nullptr )
	{
		return;
	}

#ifdef Q_OS_WIN
	auto* self = instance();
	if( qApp == nullptr || self->m_nativeFilter == nullptr )
	{
		return;
	}

	const WId id = window->winId();
	if( self->m_windows.contains( id ) )
	{
		return;
	}

	self->m_windows.insert( id );
	window->installEventFilter( self );

	// Windows 11 的窗口圆角由 DWM 负责绘制；显式声明一次，
	// 保证即便其它样式把窗口标记成 “不要圆角” 也能恢复。
	setRoundedCorners( window, true );
#else
	Q_UNUSED( window )
#endif
}


void VigilWindowFrame::setRoundedCorners( QWidget* window, bool enabled )
{
#ifdef Q_OS_WIN
	if( window == nullptr )
	{
		return;
	}

	auto* hwnd = reinterpret_cast<HWND>( window->winId() );
	if( hwnd == nullptr )
	{
		return;
	}

	const DWORD preference = enabled ? DWMWCP_ROUND : DWMWCP_DONOTROUND;
	// Win10 及更早版本会返回 E_INVALIDARG，忽略即可。
	DwmSetWindowAttribute( hwnd, DWMWA_WINDOW_CORNER_PREFERENCE,
						   &preference, sizeof( preference ) );
#else
	Q_UNUSED( window )
	Q_UNUSED( enabled )
#endif
}


void VigilWindowFrame::setDarkTitleBar( QWidget* window, bool dark )
{
#ifdef Q_OS_WIN
	if( window == nullptr )
	{
		return;
	}

	auto* hwnd = reinterpret_cast<HWND>( window->winId() );
	if( hwnd == nullptr )
	{
		return;
	}

	const BOOL value = dark ? TRUE : FALSE;
	DwmSetWindowAttribute( hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE,
						   &value, sizeof( value ) );
#else
	Q_UNUSED( window )
	Q_UNUSED( dark )
#endif
}


bool VigilWindowFrame::eventFilter( QObject* watched, QEvent* event )
{
	if( event->type() == QEvent::Show )
	{
		if( auto* widget = qobject_cast<QWidget*>( watched ) )
		{
			enable( widget );
		}
	}
	else if( event->type() == QEvent::WindowStateChange )
	{
		if( auto* widget = qobject_cast<QWidget*>( watched ) )
		{
			// 最大化时 DWM 会自动取消圆角，但部分系统版本需要手动同步。
			setRoundedCorners( widget, widget->isMaximized() == false );
		}
	}

	return QObject::eventFilter( watched, event );
}
