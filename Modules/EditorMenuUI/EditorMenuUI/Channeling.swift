//
//  Channeling.swift
//  EditorMenuUI
//
//  Created by Hoon H. on 2015/06/11.
//  Copyright (c) 2015 Eonil. All rights reserved.
//

import Foundation
import SignalGraph
import EditorModel

class Channeling {
	private let	_setup		:	()->()
	private	let	_teardown	:	()->()
	
	convenience init<T>(_ channel: ValueChannel<T>, _ handler: ValueSignal<T>->()) {
		self.init(emitter: channel.storage.emitter, handler: handler)
	}
	convenience init<T>(_ channel: ArrayChannel<T>, _ handler: ArraySignal<T>->()) {
		self.init(emitter: channel.storage.emitter, handler: handler)
	}
	private init<T>(emitter: SignalEmitter<T>, handler: T->()) {
		let	monitor		=	SignalMonitor<T>()
		monitor.handler		=	handler
		
		_setup			=	{ [emitter, monitor] in
			emitter.register(monitor)
		}
		_teardown		=	{ [emitter, monitor] in
			emitter.deregister(monitor)
		}
		_setup()
	}
	
	deinit {
		_teardown()
	}
}
