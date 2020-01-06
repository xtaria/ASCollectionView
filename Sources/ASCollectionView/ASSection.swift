// ASCollectionView. Created by Apptek Studios 2019

import Foundation
import SwiftUI

@available(iOS 13.0, *)
public struct ASCollectionViewStaticContent: Identifiable
{
	public var index: Int
	var view: AnyView

	public var id: Int { index }
}

@available(iOS 13.0, *)
public struct ASCollectionViewItemUniqueID: Hashable
{
	var sectionIDHash: Int
	var itemIDHash: Int
	init<SectionID: Hashable, ItemID: Hashable>(sectionID: SectionID, itemID: ItemID)
	{
		sectionIDHash = sectionID.hashValue
		itemIDHash = itemID.hashValue
	}
}

@available(iOS 13.0, *)
public typealias ASCollectionViewSection = ASSection

@available(iOS 13.0, *)
public struct ASSection<SectionID: Hashable>
{
	public var id: SectionID

	internal var dataSource: ASSectionDataSourceProtocol

	public var itemIDs: [ASCollectionViewItemUniqueID]
	{
		dataSource.getUniqueItemIDs(withSectionID: id)
	}

	/**
	 Initializes a  section with a datasource

	 - Parameters:
	 - id: The id for this section
	 - dataSource: The datasource
	 */
	public init<DataCollection: RandomAccessCollection, DataID: Hashable, Content: View, Container: View>(
		id: SectionID,
		dataSource: ASSectionDataSource<DataCollection, DataID, Content, Container>) where DataCollection.Index == Int
	{
		self.id = id
		self.dataSource = dataSource
	}

	/**
	 Initializes a  section with a datasource

	 - Parameters:
	 - id: The id for this section
	 - dataSource: The datasource
	 */
	public init<DataCollection: RandomAccessCollection, DataID: Hashable, Content: View, Container: View>(
		id: SectionID,
		dataSource: () -> ASSectionDataSource<DataCollection, DataID, Content, Container>) where DataCollection.Index == Int
	{
		self.id = id
		self.dataSource = dataSource()
	}
}

// MARK: STATIC CONTENT SECTION
@available(iOS 13.0, *)
public extension ASCollectionViewSection
{
	/**
	 Initializes a section with static content

	 - Parameters:
	 - id: The id for this section
	 - content: A closure returning a number of SwiftUI views to display in the collection view
	 */
	init<Container: View>(id: SectionID, container: @escaping ((AnyView) -> Container), @ViewArrayBuilder content: () -> [AnyView])
	{
		self.id = id
		dataSource = ASSectionDataSource<[ASCollectionViewStaticContent], ASCollectionViewStaticContent.ID, AnyView, Container>(
			data: content().enumerated().map
			{
				ASCollectionViewStaticContent(index: $0.offset, view: $0.element)
			},
			dataIDKeyPath: \.id,
			container: container,
			content: { staticContent, _ in staticContent.view })
	}

	init(id: SectionID, @ViewArrayBuilder content: () -> [AnyView]) {
		self.init(id: id, container: { $0 }, content: content)
	}

	/**
	 Initializes a section with a single view

	 - Parameters:
	 - id: The id for this section
	 - content: A single SwiftUI views to display in the collection view
	 */
	init<Content: View, Container: View>(id: SectionID, container: @escaping ((AnyView) -> Container), content: () -> Content)
	{
		self.id = id
		dataSource = ASSectionDataSource<[ASCollectionViewStaticContent], ASCollectionViewStaticContent.ID, AnyView, Container>(
			data: [ASCollectionViewStaticContent(index: 0, view: AnyView(content()))],
			dataIDKeyPath: \.id,
			container: container,
			content: { staticContent, _ in staticContent.view })
	}

	init<Content: View>(id: SectionID, content: () -> Content) {
		self.init(id: id, container: { $0 }, content: content)
	}
}

// MARK: Supplementary Views

@available(iOS 13.0, *)
public extension ASSection
{
	func sectionHeader<Content: View>(content: () -> Content?) -> Self
	{
		var section = self
		section.dataSource.setHeaderView(content())
		return section
	}

	func sectionFooter<Content: View>(content: () -> Content?) -> Self
	{
		var section = self
		section.dataSource.setFooterView(content())
		return section
	}

	func sectionSupplementary<Content: View>(ofKind kind: String, content: () -> Content?) -> Self
	{
		var section = self
		section.dataSource.setSupplementaryView(content(), ofKind: kind)
		return section
	}
}

// MARK: ASTableView specific modifiers

@available(iOS 13.0, *)
public extension ASSection {
	func sectionHeaderTableViewInsetGrouped<Content: View>(content: () -> Content?) -> Self
	{
		var section = self
		let insetGroupedContent =
			HStack {
				content()
				Spacer()
			}
			.font(.headline)
			.padding(EdgeInsets(top: 16, leading: 0, bottom: 6, trailing: 0))

		section.dataSource.setHeaderView(insetGroupedContent)
		return section
	}

	func tableViewSetEstimatedSizes(rowHeight: CGFloat? = nil, headerHeight: CGFloat? = nil, footerHeight: CGFloat? = nil) -> Self
	{
		var section = self
		section.dataSource.estimatedRowHeight = rowHeight
		section.dataSource.estimatedHeaderHeight = headerHeight
		section.dataSource.estimatedFooterHeight = footerHeight
		return section
	}
}
