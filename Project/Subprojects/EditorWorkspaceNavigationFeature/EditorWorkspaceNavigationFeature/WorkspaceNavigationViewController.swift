//
//  WorkspaceNavigationViewController.swift
//  EditorWorkspaceNavigationFeature
//
//  Created by Hoon H. on 2015/02/21.
//  Copyright (c) 2015 Eonil. All rights reserved.
//

import Foundation
import AppKit
import EditorCommon
import EditorUIComponents







public protocol WorkspaceNavigationViewControllerDelegate: class {
	func workpaceNavigationViewControllerWantsToOpenFileAtURL(NSURL)
}



public final class WorkspaceNavigationViewController: NSViewController {
	public weak var delegate:WorkspaceNavigationViewControllerDelegate?
	
	///	This must be a file URL to a directory with extension `eews` that contains workspace content.
	///	The directory should contain `.eonil.editor.workspace.configuration` file that contains workspace configurations.
	///	If there's no such file, this will crash program.
	public var URLRepresentation:NSURL? {
		get {
			Debug.assertMainThread()
			
			return	super.representedObject as! NSURL?
		}
		set(v) {
			Debug.assertMainThread()
			
			if v != (super.representedObject as! NSURL?) {
				if let u = URLRepresentation {
					WorkspaceSerialisation.writeRepositoryConfiguration(_internalController.repository!, toWorkspaceAtURL: u)
					_internalController.repository!.delegate	=	nil
					_internalController.repository				=	nil
				}
				
				super.representedObject	=	v
				
				if let u = URLRepresentation {
					let	u1	=	WorkspaceSerialisation.configurationFileURLForWorkspaceAtURL(u)
					if u1.existingAsAnyFile {
						_internalController.repository				=	WorkspaceSerialisation.readRepositoryConfiguration(fromWorkspaceAtURL: u)
					} else {
						_internalController.repository				=	WorkspaceRepository(name: u.lastPathComponent!)
					}
					_internalController.repository!.delegate	=	_internalController
				}
				
				self.outlineView.reloadData()
				if let n = _internalController.repository?.root {
					self._expandOpenFolderNodes(n)
				}
			}
		}
	}
	
	private func _expandOpenFolderNodes(n:WorkspaceNode) {
		Debug.assertMainThread()
		
		if n.flags.isOpenFolder {
			self.outlineView.expandItem(n, expandChildren: false)
//			self.outlineView.expandItem(self.outlineView.itemAtRow(0), expandChildren: false)
		}
		for n1 in n.children {
			_expandOpenFolderNodes(n1)
		}
	}
	
	public func synchroniseToFileSystem() {
		WorkspaceSerialisation.writeRepositoryConfiguration(_internalController.repository!, toWorkspaceAtURL: URLRepresentation!)
	}
	
	@availability(*,unavailable)
	public override var representedObject:AnyObject? {
		get {
			return	URLRepresentation
		}
		set(v) {
			precondition(v is NSURL?, "Only `NSURL` value is allowed.")
			self.URLRepresentation	=	v as! NSURL?
		}
	}
	
	public override var view:NSView {
		willSet {
			fatalError("You cannot reset `view` of this object.")
		}
	}
	public override func loadView() {
		super.view	=	NSOutlineView()
	}
	public override func viewDidLoad() {
		super.viewDidLoad()
		assert(self.view is NSOutlineView)
		
		let	c1			=	NSTableColumn()
		c1.title		=	"Name"
		c1.identifier	=	WorkspaceNavigationTreeColumnIdentifier.Name.rawValue
		
//		let	c2			=	NSTableColumn()
//		c2.title		=	"Comment"
//		c2.identifier	=	WorkspaceNavigationTreeColumnIdentifier.Comment.rawValue
		
		outlineView.addTableColumn(c1)
//		outlineView.addTableColumn(c2)
		outlineView.outlineTableColumn	=	c1
		
		outlineView.allowsMultipleSelection	=	true
		outlineView.allowsEmptySelection	=	true
		outlineView.headerView				=	nil
		outlineView.focusRingType			=	NSFocusRingType.None
//		outlineView.selectionHighlightStyle	=	NSTableViewSelectionHighlightStyle.SourceList
		outlineView.rowSizeStyle			=	NSTableViewRowSizeStyle.Small
		outlineView.menu					=	MenuController.menuOfController(_internalController.menu)
		outlineView.doubleAction			=	"dummyDoubleActionHandler:"
		
		outlineView.setDataSource(_internalController)
		outlineView.setDelegate(_internalController)
		
		_internalController.owner			=	self
	}
	
	////
	
	private let	_internalController		=	InternalController()
	
	@objc
	private func dummyDoubleActionHandler(AnyObject?) {
		
	}
}


internal extension WorkspaceNavigationViewController {
	var outlineView:NSOutlineView {
		get {
			return	self.view as! NSOutlineView
		}
	}
}










































































































///	MARK:
///	MARK:	InternalController







private final class InternalController: NSObject {
	let menu			=	WorkspaceNavigationContextMenuController()
	var repository		=	nil as WorkspaceRepository?
	
	override init() {
		super.init()
		
		let querySelection	=	{ [unowned self] ()->SelectionQuery in
			return	SelectionQuery(controller: self.owner, repository: self.repository)
		}
		menu.showInFinder.reaction	=	{ [unowned self] in
			let	q	=	querySelection()
			NSWorkspace.sharedWorkspace().activateFileViewerSelectingURLs(q.URL.all)
		}
		menu.showInTerminal.reaction	=	{ [unowned self] in
			let	q	=	querySelection()
			let	u	=	q.URL.hot!
			let	p	=	u.path!
			let	p1	=	p.stringByDeletingLastPathComponent
			let	s	=	NSAppleScript(source: "tell application \"Terminal\" to do script \"cd \(p1)\"")!
			s.executeAndReturnError(nil)
		}
		
		menu.newFile.reaction		=	{ [unowned self] in
			Debug.assertMainThread()
			
			let	q	=	querySelection()
			if let u = q.URL.hot {
				let	parentFolderURL	=	u
				let	r				=	FileUtility.createNewFileInFolder(parentFolderURL)
				if r.ok {
					let	newFileURL	=	r.value!
					let	newFileNode	=	q.node.hot!.createChildNodeAtLastAsKind(WorkspaceNodeKind.File, withName: newFileURL.lastPathComponent!)
					
					self.owner.outlineView.reloadData()
					self.owner.outlineView.expandItem(q.node.hot!)
					self.owner.outlineView.editColumn(0, row: self.owner.outlineView.rowForItem(newFileNode), withEvent: nil, select: true)
				} else {
					self.owner.presentError(r.error!)
				}
			} else {
				//	Ignore. Happens by clicking empty space.
			}
		}
		menu.newFolder.reaction		=	{ [unowned self] in
			Debug.assertMainThread()
			
			let	q	=	querySelection()
			if let u = q.URL.hot {
				let	parentFolderURL	=	u
				let	r				=	FileUtility.createNewFolderInFolder(parentFolderURL)
				if r.ok {
					let	newFolderURL	=	r.value!
					let	newFolderNode	=	q.node.hot!.createChildNodeAtLastAsKind(WorkspaceNodeKind.Folder, withName: newFolderURL.lastPathComponent!)
					
					println(newFolderURL)
					self.owner.outlineView.reloadData()
					self.owner.outlineView.expandItem(q.node.hot!)
					self.owner.outlineView.editColumn(0, row: self.owner.outlineView.rowForItem(newFolderNode), withEvent: nil, select: true)
				} else {
					self.owner.presentError(r.error!)
				}
			} else {
				//	Ignore. Happens by clicking empty space.
			}
		}
		menu.newFolderWithSelection.reaction	=	{ [unowned self] in
			let	q	=	querySelection()

			//	TODO:	Implement this...
		}
		menu.delete.reaction	=	{ [unowned self] in
			let	q	=	querySelection()
			
			let	targetURLs	=	q.URL.all
			if targetURLs.count > 0 {
				UIDialogues.queryDeletingFilesUsingWindowSheet(self.owner.outlineView.window!, files: targetURLs, handler: { (b:UIDialogueButton) -> () in
					switch b {
					case .OKButton:
						self.repository!.deleteNodes(q.node.all)
						self.owner.outlineView.reloadData()
						
						//	TODO:	filtering broken. Doesn't work correctly. Rewrite it.
						println(targetURLs)
						let	us	=	filterTopmostURLsOnlyForDeleting(targetURLs)
						println(us)
						for u in us {
							let	r	=	deleteFilesAtURLs([u])
							if let err = r.error {
								self.owner.presentError(err)
							} else {
//								self.owner.invalidateNodeForURL(u)
							}
						}
						
					case .CancelButton:
						break
					}
				})
			}
		}
		menu.addAllUnregistredFiles.reaction	=	{ [unowned self] in
			let	q	=	querySelection()
			
			fatalError("Unimplemented yet...")
			//	TODO:	Implement this...
		}
		menu.removeAllMissingFiles.reaction	=	{ [unowned self] in
			let	q	=	querySelection()
			
			fatalError("Unimplemented yet...")
			//	TODO:	Implement this...
		}
		menu.note.reaction	=	{ [unowned self] in
			let	q	=	querySelection()

			fatalError("Unimplemented yet...")
			//	TODO:	Implement this...
		}
		
		NSNotificationCenter.defaultCenter().addObserverForName(
			NSMenuDidBeginTrackingNotification,
			object: MenuController.menuOfController(menu),
			queue: nil) { [unowned self](n:NSNotification!) -> Void in
				let	q	=	querySelection()
				
				let	hasFocusSelection	=	q.node.hot != nil
				let	hasAnySelection		=	q.node.all.count > 0
				let	hasFlatSelection	=	{ ()->Bool in
					if hasAnySelection == false {
						return	false
					}
					let	a	=	q.node.all
					let	f	=	a.first!.parent
					for n in a {
						if n.parent !== f {
							return	false
						}
					}
					return	true
				}()
				let	hasAnyRootSelection	=	q.rootCoolSelection || q.rootHotSelection
				
				self.menu.showInFinder.enabled				=	hasAnySelection
				self.menu.showInTerminal.enabled			=	hasFlatSelection
				self.menu.newFile.enabled					=	hasFocusSelection && q.node.hot!.kind == WorkspaceNodeKind.Folder
				self.menu.newFolder.enabled					=	hasFocusSelection && q.node.hot!.kind == WorkspaceNodeKind.Folder
				self.menu.newFolderWithSelection.enabled	=	hasFlatSelection && hasAnyRootSelection == false
				self.menu.delete.enabled					=	hasFlatSelection && hasAnyRootSelection == false
//				self.menu.addAllUnregistredFiles.enabled	=	hasAnySelection
//				self.menu.removeAllMissingFiles.enabled		=	hasAnySelection
//				self.menu.note.enabled						=	hasFocusSelection
				self.menu.addAllUnregistredFiles.enabled	=	false
				self.menu.removeAllMissingFiles.enabled		=	false
				self.menu.note.enabled						=	false
		}
	}
	weak var owner:WorkspaceNavigationViewController! {
		willSet {
			assert(owner == nil)
		}
	}
}



///	MARK:
///	MARK:	Utility Functions

private func deleteFilesAtURLs(us: [NSURL]) -> Resolution<()> {
	Debug.assertMainThread()
	
	var	err	=	nil as NSError?
	for u in us {
		let	ok	=	NSFileManager.defaultManager().trashItemAtURL(u, resultingItemURL: nil, error: &err)
		assert(ok || err != nil)
		if !ok {
			return	Resolution.failure(err!)
		}
	}
	return	Resolution.success()
}
private func filterTopmostURLsOnlyForDeleting(urls:[NSURL]) -> [NSURL] {
	var	us1	=	[] as [NSURL]
	for u in urls {
		//	TODO:	Currenyl O(n^2). There seems to be a better way...
		let	dupc	=	urls.reduce(0) { sum, u1 in
			return	sum + (u.absoluteString!.hasPrefix(u1.absoluteString!) ? 1 : 0)
		}
		
		if dupc > 1 {
			continue
		} else {
			us1.append(u)
		}
	}
	return	us1
}


























///	MARK:
///	MARK:	InternalController (NSOutlineViewDataSource)



extension InternalController: NSOutlineViewDataSource {
	@objc
	func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
		let n	=	item as! WorkspaceNode
		return	n.kind == WorkspaceNodeKind.Folder
	}
	@objc
	func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
		if item == nil {
			return	repository == nil ? 0 : 1
		}
		let n	=	item as! WorkspaceNode
		return	n.children.count
	}
	@objc
	func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
		if item == nil {
			return	repository!.root
		}
		let	n	=	item as! WorkspaceNode
		return	n.children[index]
	}
	@objc
	func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
		return	item as! WorkspaceNode
	}
	@objc
	func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
		let	cid	=	WorkspaceNavigationTreeColumnIdentifier(rawValue: tableColumn!.identifier)!
		let	v	=	CellView(cid)
		let	n	=	item as! WorkspaceNode
		v.nodeRepresentation	=	n
		v.textField!.delegate	=	self
		return	v
	}
}










///	MARK:	InternalController (NSOutlineViewDelegate)



extension InternalController: NSOutlineViewDelegate {
	@objc
	private func outlineView(outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
		let	n	=	item as! WorkspaceNode
		if n.kind == WorkspaceNodeKind.File {
			let	u	=	owner.URLRepresentation!
			let	u1	=	u.URLByAppendingPath(n.path)
			owner.delegate?.workpaceNavigationViewControllerWantsToOpenFileAtURL(u1)
		}
		return	true
	}
	@objc
	func outlineView(outlineView: NSOutlineView, shouldExpandItem item: AnyObject) -> Bool {
		let	n	=	item as! WorkspaceNode
		n.setExpanded()
		owner.synchroniseToFileSystem()
		return	true
	}
	@objc
	func outlineView(outlineView: NSOutlineView, shouldCollapseItem item: AnyObject) -> Bool {
		let	n	=	item as! WorkspaceNode
		n.setCollapsed()
		owner.synchroniseToFileSystem()
		return	true
	}
}







































///	MARK:	InternalController (WorkspaceRepositoryDelegate)

extension InternalController: WorkspaceRepositoryDelegate {
	func workspaceRepositoryWillCreateNode() {
		
	}
	func workspaceRepositoryDidCreateNode(node: WorkspaceNode) {
		owner.synchroniseToFileSystem()
	}
	func workspaceRepositoryWillRenameNode(node: WorkspaceNode) {
		
	}
	func workspaceRepositoryDidRenameNode(node: WorkspaceNode) {
		owner.synchroniseToFileSystem()
	}
	func workspaceRepositoryWillMoveNode(node: WorkspaceNode) {
	}
	func workspaceRepositoryDidMoveNode(node: WorkspaceNode) {
		owner.synchroniseToFileSystem()
	}
	func workspaceRepositoryWillDeleteNode(node: WorkspaceNode) {
	}
	func workspaceRepositoryDidDeleteNode() {
		owner.synchroniseToFileSystem()		
	}
	
	
	
	func workspaceRepositoryDidOpenSubworkspaceAtNode(node: WorkspaceNode) {
		
	}
	func workspaceRepositoryWillCloseSubworkspaceAtNode(node: WorkspaceNode) {
		
	}
}












///	MARK:	InternalController (NSTextFieldDelegate)

//	Commented methods are not being called. I don't know why.
extension InternalController: NSTextFieldDelegate {
//	private func control(control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
//		return	true
//	}
//	private func control(control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
//		return	true
//	}
	private override func controlTextDidBeginEditing(obj: NSNotification) {
		
	}
	private override func controlTextDidChange(obj: NSNotification) {
		
	}
	
	///	Called only when user committed editing. 
	///	No call if user cancanlled editing by pressing ESC key.
	private override func controlTextDidEndEditing(obj: NSNotification) {
		//	A bit hacky...
		let	tf	=	obj.object as! NSTextField
		let	c	=	tf.superview as! CellView
		let	n	=	c.nodeRepresentation!
		
		let	pc	=	tf.stringValue
		let	u1	=	owner.URLRepresentation!.URLByAppendingPath(n.path)
		let	u2	=	u1.URLByDeletingLastPathComponent!.URLByAppendingPathComponent(pc)
		var	e	=	nil as NSError?
		let	ok	=	NSFileManager.defaultManager().moveItemAtURL(u1, toURL: u2, error: &e)
		if ok {
			n.rename(pc)
		} else {
			Debug.log(u1)
			Debug.log(u2)
			tf.stringValue	=	n.name
			self.owner.presentError(e!)
		}
	}
}




