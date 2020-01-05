// ASCollectionView. Created by Apptek Studios 2019

import Foundation
import SwiftUI

public struct ASCollectionViewStaticContent: Identifiable
{
	public var index: Int
	var view: AnyView

	public var id: Int { index }
}

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

public typealias ASCollectionViewSection = ASSection
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
	public init<DataCollection: RandomAccessCollection, DataID: Hashable, Content: View>(
		id: SectionID,
		dataSource: ASSectionDataSource<DataCollection, DataID, Content, Content>) where DataCollection.Index == Int
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
	public init<DataCollection: RandomAccessCollection, DataID: Hashable, Content: View>(
		id: SectionID,
		dataSource: () -> ASSectionDataSource<DataCollection, DataID, Content, Content>) where DataCollection.Index == Int
	{
		self.id = id
		self.dataSource = dataSource()
	}
}

// MARK: STATIC CONTENT SECTION

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
