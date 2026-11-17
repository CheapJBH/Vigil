/*
 * VigilWindowFrame.h - frameless window helper for Vigil
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

#pragma once

#include <QObject>
#include <QSet>
#include <QtGlobal>
#include <qwindowdefs.h>

class QWidget;
class QAbstractNativeEventFilter;

// Windows: 去掉系统标题栏，让客户区覆盖整个窗口，同时保留 DWM 的
// 圆角、投影、贴边缩放（Aero Snap）和最大化动画。
//
// 做法与纯 Qt 的 FramelessWindowHint 不同：窗口仍然是普通顶层窗口，
// 我们只拦截 WM_NCCALCSIZE 把非客户区吞掉，所以系统行为不受影响。
// 其他平台不做任何事。
class VigilWindowFrame : public QObject
{
	Q_OBJECT

public:
	// 对同一个窗口重复调用是安全的。
	static void enable( QWidget* window );

	// 按 Windows 11 规范给窗口设置 8px 圆角（Win10 会忽略）。
	static void setRoundedCorners( QWidget* window, bool enabled = true );

	// 让标题栏区域在最大化状态下也保持 1px 的边框色，
	// 避免窗口与屏幕边缘糊在一起。
	static void setDarkTitleBar( QWidget* window, bool dark );

	// 供原生事件过滤器查询。Windows 之外的平台恒为 false。
	bool handlesWindow( WId id ) const { return m_windows.contains( id ); }

protected:
	bool eventFilter( QObject* watched, QEvent* event ) override;

private:
	VigilWindowFrame();
	~VigilWindowFrame() override;

	static VigilWindowFrame* instance();

	QSet<WId> m_windows;
	QAbstractNativeEventFilter* m_nativeFilter = nullptr;
};
