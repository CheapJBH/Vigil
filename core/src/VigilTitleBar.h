/*
 * VigilTitleBar.h - custom Windows 11 style title bar for Vigil
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

#include <QAbstractButton>
#include <QPoint>
#include <QWidget>

#ifndef VIGIL_CORE_EXPORT
#  if defined( vigil_core_EXPORTS )
#    define VIGIL_CORE_EXPORT Q_DECL_EXPORT
#  else
#    define VIGIL_CORE_EXPORT Q_DECL_IMPORT
#  endif
#endif

class QLabel;
class QHBoxLayout;
class QMenu;

// 自绘的窗口按钮：最小化 / 最大化 / 还原 / 关闭。
// 用 QPainter 画几何图形而不是字体符号，避免不同 Windows 版本上
// 符号被渲染成 emoji 或者缺字形。
class VIGIL_CORE_EXPORT VigilTitleButton : public QAbstractButton
{
	Q_OBJECT

public:
	enum Kind
	{
		Minimize,
		Maximize,
		Restore,
		Close
	};

	explicit VigilTitleButton( Kind kind, QWidget* parent = nullptr );

	void setKind( Kind kind );
	Kind kind() const { return m_kind; }

protected:
	void paintEvent( QPaintEvent* event ) override;
	void enterEvent( QEnterEvent* event ) override;
	void leaveEvent( QEvent* event ) override;

private:
	Kind m_kind;
	bool m_hover = false;
};


// 40px 高的自绘标题栏：应用图标 + 标题 + 可选菜单按钮 + 窗口控制按钮。
// 拖动、双击最大化都自己处理；窗口本身由 VigilWindowFrame 去掉系统标题栏。
class VIGIL_CORE_EXPORT VigilTitleBar : public QWidget
{
	Q_OBJECT

public:
	explicit VigilTitleBar( QWidget* window, QWidget* parent = nullptr );

	void setHeading( const QString& text );
	void addMenu( QMenu* menu );

protected:
	void paintEvent( QPaintEvent* event ) override;
	void mousePressEvent( QMouseEvent* event ) override;
	void mouseMoveEvent( QMouseEvent* event ) override;
	void mouseReleaseEvent( QMouseEvent* event ) override;
	void mouseDoubleClickEvent( QMouseEvent* event ) override;
	bool eventFilter( QObject* watched, QEvent* event ) override;

private:
	void toggleMaximize();
	void updateMaximizeButton();

	QWidget* m_window = nullptr;
	QLabel* m_iconLabel = nullptr;
	QLabel* m_titleLabel = nullptr;
	QHBoxLayout* m_menuLayout = nullptr;
	VigilTitleButton* m_minButton = nullptr;
	VigilTitleButton* m_maxButton = nullptr;
	VigilTitleButton* m_closeButton = nullptr;

	QPoint m_pressGlobalPos;
	QPoint m_dragOffset;
	bool m_dragging = false;
	bool m_systemMoveStarted = false;
};
