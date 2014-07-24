//
//  XPathQuery.swift
//  NDHpple
//
//  Created by Nicolai on 24/06/14.
//  Copyright (c) 2014 Nicolai Davidsson. All rights reserved.
//

import Foundation

func createNode(currentNode: xmlNodePtr, inout parentDictionary: Dictionary<String, AnyObject>, parentContent: Bool) -> Dictionary<String, AnyObject>? {
	
	var resultForNode = Dictionary<String, AnyObject>(minimumCapacity: 8)
	
	if currentNode.memory.name.getLogicValue() {
		
		let name = String.fromCString(ConstUnsafePointer<CChar>(currentNode.memory.name))
		if let name=name
		{
			resultForNode.updateValue(name, forKey: NDHppleNodeKey.Name.toRaw())
		}
	}
	
	if currentNode.memory.content.getLogicValue() {
		
		let cstring = ConstUnsafePointer<CChar>(currentNode.memory.content)
		let content = String.fromCString(cstring)
		if let content=content
		{
			if resultForNode[NDHppleNodeKey.Name.toRaw()] as AnyObject? as? String == "text" {
				
				if parentContent {
					
					parentDictionary.updateValue(content, forKey: NDHppleNodeKey.Content.toRaw())
					return nil
				}
				
				resultForNode.updateValue(content, forKey: NDHppleNodeKey.Content.toRaw())
				return resultForNode
			} else {
				
				resultForNode.updateValue(content, forKey: NDHppleNodeKey.Content.toRaw())
			}
		}
	}
	
	var attribute = currentNode.memory.properties
	if attribute.getLogicValue() {
		
		var attributeArray = Array<Dictionary<String, AnyObject>>()
		
		while attribute.getLogicValue() {
			
			var attributeDictionary = Dictionary<String, AnyObject>()
			let attributeName = attribute.memory.name
			if attributeName.getLogicValue() {
				if let v=String.fromCString(ConstUnsafePointer<CChar>(attributeName))
				{
					attributeDictionary.updateValue(v, forKey: NDHppleNodeKey.AttributeName.toRaw())
				}
			}
			
			if attribute.memory.children.getLogicValue() {
				
				if let childDictionary = createNode(attribute.memory.children, &attributeDictionary, true) {
					
					attributeDictionary.updateValue(childDictionary, forKey: NDHppleNodeKey.AttributeContent.toRaw())
				}
			}
			
			if attributeDictionary.count > 0 {
				
				attributeArray += attributeDictionary
			}
			
			attribute = attribute.memory.next
		}
		
		if attributeArray.count > 0 {
			
			resultForNode.updateValue(attributeArray, forKey: NDHppleNodeKey.AttributeArray.toRaw())
		}
	}
	
	var childNode = currentNode.memory.children
	if childNode {
		
		var childContentArray = Array<Dictionary<String, AnyObject>>()
		
		while childNode {
			
			if let childDictionary = createNode(childNode, &resultForNode, false) {
				
				childContentArray += childDictionary
			}
			
			childNode = childNode.memory.next
		}
		
		if childContentArray.count > 0 {
			
			resultForNode.updateValue(childContentArray, forKey: NDHppleNodeKey.Children.toRaw())
		}
	}
	
	let buffer = xmlBufferCreate()
	xmlNodeDump(buffer, currentNode.memory.doc, currentNode, 0, 0)
	if let v=String.fromCString(ConstUnsafePointer<CChar>(buffer.memory.content))
	{
		resultForNode.updateValue(v, forKey: "raw")
	}
	xmlBufferFree(buffer)
	
	return resultForNode
}

func PerformXPathQuery(data: NSString, query: String, isXML: Bool) -> Array<Dictionary<String, AnyObject>>? {
	
	var result: Array<Dictionary<String, AnyObject>>?
	
	let bytes = data.cStringUsingEncoding(NSUTF8StringEncoding)
	let length = CInt(data.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
	let url = ""// as ConstUnsafePointer<CChar>
	let encoding = CFStringGetCStringPtr(nil, 0)
	let options: CInt = isXML ? 1 : ((1 << 5) | (1 << 6))
	
	var function = isXML ? xmlReadMemory : htmlReadMemory
	let doc = function(bytes, length, url, encoding, options)
	
	if doc.getLogicValue() {
		
		let xPathCtx = xmlXPathNewContext(doc)
		if xPathCtx {
			
			var queryBytes = query.cStringUsingEncoding(NSUTF8StringEncoding)!
			let ptr: UnsafePointer<CChar> = &queryBytes
			
			let xPathObj = xmlXPathEvalExpression(UnsafePointer<CUnsignedChar>(ptr.value), xPathCtx)
			if xPathObj.getLogicValue() {
				
				let nodes = xPathObj.memory.nodesetval
				if nodes.getLogicValue() {
					
					var resultNodes  = Array<Dictionary<String, AnyObject>>()
					let nodesArray = UnsafeArray(start: nodes.memory.nodeTab, length: Int(nodes.memory.nodeNr))
					var dummy = Dictionary<String, AnyObject>()
					for rawNode in nodesArray {
						
						if let node = createNode(rawNode, &dummy, false) {
							
							resultNodes.append(node)
						}
					}
					
					result = resultNodes
				}
				
				xmlXPathFreeObject(xPathObj)
			}
			
			xmlXPathFreeContext(xPathCtx)
		}
		
		xmlFreeDoc(doc)
	}
	
	return result
}

func PerformXMLXPathQuery(data: String, query: String) -> Array<Dictionary<String, AnyObject>>? {
	
	return PerformXPathQuery(data, query, true)
}

func PerformHTMLXPathQuery(data: String, query: String) -> Array<Dictionary<String, AnyObject>>? {
	
	return PerformXPathQuery(data, query, false)
}