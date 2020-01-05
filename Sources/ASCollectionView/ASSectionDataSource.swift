// ASCollectionView. Created by Apptek Studios 2019

import Foundation
import SwiftUI

internal protocol ASSectionDataSourceProtocol
{
	func getIndexPaths(withSectionIndex sectionIndex: Int) -> [IndexPath]
	func getUniqueItemIDs<SectionID: Hashable>(withSectionID sectionID: SectionID) -> [ASCollectionViewItemUniqueID]
	func configureHostingController(reusingController: ASHostingControllerProtocol?, forItemID itemID: ASCollectionViewItemUniqueID, isSelected: Bool) -> ASHostingControllerProtocol?
	func getTypeErasedData(for indexPath: IndexPath) -> Any?
	var supplementaryKinds: Set<String> { get }
	func supplementary(ofKind kind: String) -> AnyView?

	func onAppear(_ indexPath: IndexPath)
	func onDisappear(_ indexPath: IndexPath)
	func prefetch(_ indexPaths: [IndexPath])
	func cancelPrefetch(_ indexPaths: [IndexPath])
	func getDragItem(for indexPath: IndexPath) -> UIDragItem?
	func removeItem(from indexPath: IndexPath)
	func insertDragItems(_ items: [UIDragItem], at indexPath: IndexPath)
	func supportsDelete(at indexPath: IndexPath) -> Bool
	func onDelete(indexPath: IndexPath, completionHandler: (Bool) -> Void)
	var dragEnabled: Bool { get }
	var dropEnabled: Bool { get }

	var estimatedRowHeight: CGFloat? { get }
	var estimatedHeaderHeight: CGFloat? { get }
	var estimatedFooterHeight: CGFloat? { get }
}

public enum CellEvent<Data>
{
	/// Respond by starting necessary prefetch operations for this data to be displayed soon (eg. download images)
	case prefetchForData(data: [Data])

	/// Called when its no longer necessary to prefetch this data
	case cancelPrefetchForData(data: [Data])

	/// Called when an item is appearing on the screen
	case onAppear(item: Data)

	/// Called when an item is disappearing from the screen
	case onDisappear(item: Data)
}

public enum DragDrop<Data>
{
	case onRemoveItem(indexPath: IndexPath)
	case onAddItems(items: [Data], atIndexPath: IndexPath)
}

public typealias OnCellEvent<Data> = ((_ event: CellEvent<Data>) -> Void)
public typealias OnDragDrop<Data> = ((_ event: DragDrop<Data>) -> Void)
public typealias ItemProvider<Data> = ((_ item: Data) -> NSItemProvider)
public typealias OnSwipeToDelete<Data> = ((Data, _ completionHandler: (Bool) -> Void) -> Void)

public struct CellContext
{
	public var isSelected: Bool
	public var isFirstInSection: Bool
	public var isLastInSection: Bool
}

public struct ASSectionDataSource<DataCollection: RandomAccessCollection, DataID: Hashable, Content: View, Container: View>: ASSectionDataSourceProtocol where DataCollection.Index == Int
{
	var data: DataCollection
	var dataIDKeyPath: KeyPath<DataCollection.Element, DataID>
	var container: (Content) -> Container
	var content: (DataCollection.Element, CellContext) -> Content

	var supplementaryViews: [String: AnyView] = [:]
	var onCellEvent: OnCellEvent<DataCollection.Element>?
	var onDragDrop: OnDragDrop<DataCollection.Element>?
	var itemProvider: ItemProvider<DataCollection.Element>?
	var onSwipeToDelete: OnSwipeToDelete<DataCollection.Element>?

	// Only relevant for ASTableView
	public var estimatedRowHeight: CGFloat?
	public var estimatedHeaderHeight: CGFloat?
	public var estimatedFooterHeight: CGFloat?

	// MARK: Calculated vars

	var dragEnabled: Bool { onDragDrop != nil }
	var dropEnabled: Bool { onDragDrop != nil }

	var supplementaryKinds: Set<String>
	{
		Set(supplementaryViews.keys)
	}

	func supplementary(ofKind kind: String) -> AnyView?
	{
		supplementaryViews[kind]
	}

	func cellContext(forItemID itemID: ASCollectionViewItemUniqueID, isSelected: Bool) -> CellContext
	{
		CellContext(
			isSelected: isSelected,
			isFirstInSection: data.first?[keyPath: dataIDKeyPath].hashValue == itemID.itemIDHash,
			isLastInSection: data.last?[keyPath: dataIDKeyPath].hashValue == itemID.itemIDHash)
	}

	func configureHostingController(reusingController: ASHostingControllerProtocol? = nil, forItemID itemID: ASCollectionViewItemUniqueID, isSelected: Bool) -> ASHostingControllerProtocol?
	{
		guard let item = data.first(where: { $0[keyPath: dataIDKeyPath].hashValue == itemID.itemIDHash }) else { return nil }
		let view = content(item, cellContext(forItemID: itemID, isSelected: isSelected))
		let containedView = container(view)

		if let existingHC = reusingController as? ASHostingController<Container>
		{
			existingHC.setView(containedView)
			return existingHC
		}
		else
		{
			let newHC = ASHostingController<Container>(containedView)
			return newHC
		}
	}

	func getTypeErasedData(for indexPath: IndexPath) -> Any?
	{
		data[safe: indexPath.item]
	}

	func getIndexPaths(withSectionIndex sectionIndex: Int) -> [IndexPath]
	{
		data.indices.map { IndexPath(item: $0, section: sectionIndex) }
	}

	func getUniqueItemIDs<SectionID: Hashable>(withSectionID sectionID: SectionID) -> [ASCollectionViewItemUniqueID]
	{
		data.map
		{
			ASCollectionViewItemUniqueID(sectionID: sectionID, itemID: $0[keyPath: dataIDKeyPath])
		}
	}

	func onAppear(_ indexPath: IndexPath)
	{
		guard let item = data[safe: indexPath.item] else { return }
		onCellEvent?(.onAppear(item: item))
	}

	func onDisappear(_ indexPath: IndexPath)
	{
		guard let item = data[safe: indexPath.item] else { return }
		onCellEvent?(.onDisappear(item: item))
	}

	func prefetch(_ indexPaths: [IndexPath])
	{
		let dataToPrefetch: [DataCollection.Element] = indexPaths.compactMap
		{
			data[safe: $0.item]
		}
		onCellEvent?(.prefetchForData(data: dataToPrefetch))
	}

	func cancelPrefetch(_ indexPaths: [IndexPath])
	{
		let dataToCancelPrefetch: [DataCollection.Element] = indexPaths.compactMap
		{
			data[safe: $0.item]
		}
		onCellEvent?(.cancelPrefetchForData(data: dataToCancelPrefetch))
	}

	func supportsDelete(at indexPath: IndexPath) -> Bool
	{
		onSwipeToDelete != nil
	}

	func onDelete(indexPath: IndexPath, completionHandler: (Bool) -> Void)
	{
		guard let item = data[safe: indexPath.item] else { return }
		onSwipeToDelete?(item, completionHandler)
	}

	func getDragItem(for indexPath: IndexPath) -> UIDragItem?
	{
		guard dragEnabled else { return nil }
		guard let item = data[safe: indexPath.item] else { return nil }

		let itemProvider: NSItemProvider = self.itemProvider?(item) ?? NSItemProvider()
		let dragItem = UIDragItem(itemProvider: itemProvider)
		dragItem.localObject = item
		return dragItem
	}

	func removeItem(from indexPath: IndexPath)
	{
		guard data.containsIndex(indexPath.item) else { return }
		onDragDrop?(.onRemoveItem(indexPath: indexPath))
	}

	func insertDragItems(_ items: [UIDragItem], at indexPath: IndexPath)
	{
		guard dropEnabled else { return }
		let index = max(data.startIndex, min(indexPath.item, data.endIndex))
		let indexPath = IndexPath(item: index, section: indexPath.section)
		let dataItems = items.compactMap
		{ (dragItem) -> DataCollection.Element? in
			guard let item = dragItem.localObject as? DataCollection.Element else { return nil }
			return item
		}
		onDragDrop?(.onAddItems(items: dataItems, atIndexPath: indexPath))
	}
}

// MARK: SUPPLEMENTARY VIEWS - INTERNAL

internal extension ASSectionDataSource
{
	mutating func setHeaderView<Content: View>(_ view: Content?)
	{
		setSupplementaryView(view, ofKind: UICollectionView.elementKindSectionHeader)
	}

	mutating func setFooterView<Content: View>(_ view: Content?)
	{
		setSupplementaryView(view, ofKind: UICollectionView.elementKindSectionFooter)
	}

	mutating func setSupplementaryView<Content: View>(_ view: Content?, ofKind kind: String)
	{
		guard let view = view else
		{
			supplementaryViews.removeValue(forKey: kind)
			return
		}

		supplementaryViews[kind] = AnyView(view)
	}
}

// MARK: PUBLIC Initialisers

public extension ASSectionDataSource {
	/**
	 Initializes a  section with data

	 - Parameters:
	 - id: The id for this section
	 - data: The data to display in the section. This initialiser expects data that conforms to 'Identifiable'
	 - dataID: The keypath to a hashable identifier of each data item
	 - onCellEvent: Use this to respond to cell appearance/disappearance, and preloading events.
	 - onDragDropEvent: Define this closure to enable drag/drop and respond to events (default is nil: drag/drop disabled)
	 - contentBuilder: A closure returning a SwiftUI view for the given data item
	 */
	init(
		data: DataCollection,
		id dataIDKeyPath: KeyPath<DataCollection.Element, DataID>,
		container: @escaping ((Content) -> Container),
		@ViewBuilder contentBuilder: @escaping ((DataCollection.Element, CellContext) -> Content))
	{
		self.data = data
		self.dataIDKeyPath = dataIDKeyPath
		self.container = container
		content = contentBuilder
	}
}

public extension ASSectionDataSource where Container == Content
{
	init(
		data: DataCollection,
		id dataIDKeyPath: KeyPath<DataCollection.Element, DataID>,
		@ViewBuilder contentBuilder: @escaping ((DataCollection.Element, CellContext) -> Content))
	{
		self.data = data
		self.dataIDKeyPath = dataIDKeyPath
		container = { $0 }
		content = contentBuilder
	}
}

// MARK: STATIC CONTENT SECTION

/*
 public extension ASSectionDataSource where DataCollection == [ASCollectionViewStaticContent], DataID == ASCollectionViewStaticContent.ID, Content == AnyView, Container == Content
 {
 /**
      Initializes a section with static content

      - Parameters:
      - id: The id for this section
      - content: A closure returning a number of SwiftUI views to display in the collection view
  */
 init(@ViewArrayBuilder content: () -> [AnyView])
 {
 	self.data = content().enumerated().map
 		{
 			ASCollectionViewStaticContent(index: $0.offset, view: $0.element)
 	}
 	self.dataIDKeyPath = \.id
 	self.container = { $0 }
 	self.content = { staticContent, _ in staticContent.view }
 }

 /**
      Initializes a section with a single view

      - Parameters:
      - id: The id for this section
      - content: A single SwiftUI views to display in the collection view
  */
 init<StaticItem: View>(container: @escaping ((AnyView) -> Container), content: () -> StaticItem)
 {
 	self.data = [ASCollectionViewStaticContent(index: 0, view: AnyView(content()))]
 	self.dataIDKeyPath = \.id
 	self.container = { $0 }
 	self.content = { staticContent, _ in staticContent.view }
 }

 }*/

// MARK: IDENTIFIABLE DATA SECTION

public extension ASSectionDataSource where DataCollection.Element: Identifiable, DataID == DataCollection.Element.ID
{
	/**
	 Initializes a  section with identifiable data

	 - Parameters:
	 - id: The id for this section
	 - data: The data to display in the section. This initialiser expects data that conforms to 'Identifiable'
	 - onCellEvent: Use this to respond to cell appearance/disappearance, and preloading events.
	 - onDragDropEvent: Define this closure to enable drag/drop and respond to events (default is nil: drag/drop disabled)
	 - contentBuilder: A closure returning a SwiftUI view for the given data item
	 */
	init(
		data: DataCollection,
		container: @escaping ((Content) -> Container),
		@ViewBuilder contentBuilder: @escaping ((DataCollection.Element, CellContext) -> Content))
	{
		self.data = data
		dataIDKeyPath = \.id
		self.container = container
		content = contentBuilder
	}
}

public extension ASSectionDataSource where DataCollection.Element: Identifiable, DataID == DataCollection.Element.ID, Container == Content
{
	init(
		data: DataCollection,
		@ViewBuilder contentBuilder: @escaping ((DataCollection.Element, CellContext) -> Content))
	{
		self.init(data: data, container: { $0 }, contentBuilder: contentBuilder)
	}
}

// MARK: PUBLIC MODIFIERS

public extension ASSectionDataSource {
	func onCellEvent(_ onCellEvent: OnCellEvent<DataCollection.Element>?) -> Self
	{
		var dataSource = self
		dataSource.onCellEvent = onCellEvent
		return dataSource
	}

	func onDragDropEvent(_ onDragDropEvent: OnDragDrop<DataCollection.Element>?) -> Self
	{
		var dataSource = self
		dataSource.onDragDrop = onDragDropEvent
		return dataSource
	}

	func itemProvider(_ itemProvider: ItemProvider<DataCollection.Element>?) -> Self
	{
		var dataSource = self
		dataSource.itemProvider = itemProvider
		return dataSource
	}

	func onSwipeToDelete(_ onSwipeToDelete: OnSwipeToDelete<DataCollection.Element>?) -> Self
	{
		var dataSource = self
		dataSource.onSwipeToDelete = onSwipeToDelete
		return dataSource
	}
}

public extension ASSectionDataSource
{
	func sectionHeader<Content: View>(content: () -> Content?) -> Self
	{
		var dataSource = self
		dataSource.setHeaderView(content())
		return dataSource
	}

	func sectionFooter<Content: View>(content: () -> Content?) -> Self
	{
		var dataSource = self
		dataSource.setFooterView(content())
		return dataSource
	}

	func sectionSupplementary<Content: View>(ofKind kind: String, content: () -> Content?) -> Self
	{
		var dataSource = self
		dataSource.setSupplementaryView(content(), ofKind: kind)
		return dataSource
	}
}

// MARK: ASTableView specific modifiers

public extension ASSectionDataSource {
	func sectionHeaderTableViewInsetGrouped<Content: View>(content: () -> Content?) -> Self
	{
		var dataSource = self
		let insetGroupedContent =
			HStack {
				content()
				Spacer()
			}
			.font(.headline)
			.padding(EdgeInsets(top: 12, leading: 0, bottom: 6, trailing: 0))

		dataSource.setHeaderView(insetGroupedContent)
		return dataSource
	}

	func tableViewSetEstimatedSizes(rowHeight: CGFloat? = nil, headerHeight: CGFloat? = nil, footerHeight: CGFloat? = nil) -> Self
	{
		var dataSource = self
		dataSource.estimatedRowHeight = rowHeight
		dataSource.estimatedHeaderHeight = headerHeight
		dataSource.estimatedFooterHeight = footerHeight
		return dataSource
	}
}
