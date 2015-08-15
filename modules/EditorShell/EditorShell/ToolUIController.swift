//
//  ToolUIController.swift
//  EditorShell
//
//  Created by Hoon H. on 2015/08/14.
//  Copyright © 2015 Eonil. All rights reserved.
//

import Foundation
import AppKit
import EditorModel

class ToolUIController: ModelConsumerNode {

	override init() {
		super.init()
	}
	deinit {
	}

	var toolbar: NSToolbar {
		get {
			return	_toolbar
		}
	}

	func run() {
		assert(_isRunning == false)
		_isRunning	=	true
		_installToolItems()
	}
	func halt() {
		assert(_isRunning == true)
		_deinstallToolItems()
		_isRunning	=	false
	}

	///

	var onTest1: (()->())?
	var onTest2: (()->())?

	///

	private let	_toolbar	=	NSToolbar(identifier: _TOOLBAR_ID)
	private let	_agent		=	_ToolbarAgent()

	private let	_divsel		=	NSSegmentedControl()

	private var	_isRunning	=	false

	private func _installToolItems() {
		_divsel.segmentCount	=	3
		_divsel.setLabel("Navigator", forSegment: 0)
		_divsel.setLabel("Editor", forSegment: 1)
		_divsel.setLabel("Inspector", forSegment: 2)
		_divsel.sizeToFit()

		_toolbar.displayMode	=	.IconOnly

		_agent.owner		=	self
		_toolbar.delegate	=	_agent
	}
	private func _deinstallToolItems() {
		_toolbar.delegate	=	nil
		_agent.owner		=	nil
	}
}










private final class _ToolbarAgent: NSObject, NSToolbarDelegate {
	weak var owner: ToolUIController?
	@objc
	private func toolbar(toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		assert(owner != nil)
		if _isKnownSystemIdentifier(itemIdentifier) {
			return	NSToolbarItem(itemIdentifier: itemIdentifier)
		}
		else {
			if itemIdentifier.hasPrefix("EDITOR_") {
				let	subcode	=	itemIdentifier["EDITOR_".endIndex..<itemIdentifier.endIndex]
				if let id = _EditorToolItemID(rawValue: subcode) {
					switch id {
					case .Test1:		return	_instantiateTest1ToolbarItem(self)
					case .Test2:		return	_instantiateTest2ToolbarItem(self)
					case .DivisionSelector:	return	_instantiateCustomViewToolbarItem(.DivisionSelector, view: owner!._divsel, label: "Division")
					}
				}
			}
			fatalError("Unknown item-identifier `\(itemIdentifier)` found and could not be processed.")
		}
	}
	@objc
	private func toolbarAllowedItemIdentifiers(toolbar: NSToolbar) -> [String] {
		assert(owner != nil)
		return	_allowedItemIDs().map({ $0.toolbarItemIdentifier() })
	}
	@objc
	private func toolbarDefaultItemIdentifiers(toolbar: NSToolbar) -> [String] {
		assert(owner != nil)
		return	_defaultItemIDs().map({ $0.toolbarItemIdentifier() })
	}

	@objc
	func test1(_: AnyObject?) {
		assert(owner != nil)
		assert(owner!.onTest1 != nil)
		owner!.onTest1?()
	}
	@objc
	func test2(_: AnyObject?) {
		assert(owner != nil)
		assert(owner!.onTest2 != nil)
		owner!.onTest2?()
	}
}















private func _instantiateTest1ToolbarItem(agent: _ToolbarAgent) -> NSToolbarItem {
	let	m	=	NSToolbarItem(itemIdentifier: _EditorToolItemID.Test1.toolbarItemIdentifier())
	m.label		=	"Test 1"
	m.paletteLabel	=	"Test 1"
	m.target	=	agent
	m.action	=	"test1:"
	return	m
}
private func _instantiateTest2ToolbarItem(agent: _ToolbarAgent) -> NSToolbarItem {

	let	m	=	NSToolbarItem(itemIdentifier: _EditorToolItemID.Test2.toolbarItemIdentifier())
	m.label		=	"Test 2"
	m.paletteLabel	=	"Test 2"
	m.target	=	agent
	m.action	=	"test2:"
	return	m
}
private func _instantiateCustomViewToolbarItem(id: _EditorToolItemID, view: NSView, label: String) -> NSToolbarItem {
	let	m	=	NSToolbarItem(itemIdentifier: id.toolbarItemIdentifier())
	m.label		=	label
	m.paletteLabel	=	label
	m.view		=	view
	return	m
}
















private func _defaultItemIDs() -> [_ToolItemID] {
	return	_allowedItemIDs()
}
private func _allowedItemIDs() -> [_ToolItemID] {
	return	[
		.Editor(.Test1),
		.Editor(.Test2),
		.System(NSToolbarFlexibleSpaceItemIdentifier),
		.Editor(.DivisionSelector),
	]
}

private enum _ToolItemID {
	case System(String)
	case Editor(_EditorToolItemID)

	func toolbarItemIdentifier() -> String {
		switch self {
		case .System(let code):
			return	code
		case .Editor(let id):
			return	id.toolbarItemIdentifier()
		}
	}

}
private enum _EditorToolItemID: String {
	case Test1
	case Test2

	case DivisionSelector

	func toolbarItemIdentifier() -> String {
		return	"EDITOR_\(self.rawValue)"
	}
}

private func _isKnownSystemIdentifier(itemIdentifier: String) -> Bool {
	let	list	=	[
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarShowColorsItemIdentifier,
		NSToolbarShowFontsItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarPrintItemIdentifier,
	]
	let	set	=	Set(list)
	return	set.contains(itemIdentifier)
}

private let	_TOOLBAR_ID	=	"Root/Tool"













