// ASCollectionView. Created by Apptek Studios 2019

import ASCollectionView
import MagazineLayout
import SwiftUI
import UIKit

struct MagazineLayoutScreen: View
{
	@State var data: [[Post]] = (0 ... 5).map
	{
		DataSource.postsForGridSection($0, number: 10)
	}

	var sections: [ASSection<Int>]
	{
		data.enumerated().map
		{ (arg) -> ASSection<Int> in

			let (offset, sectionData) = arg
			return ASSection(id: offset) {
				ASSectionDataSource(data: sectionData)
				{ item, _ in
					ASRemoteImageView(item.url)
						.aspectRatio(1, contentMode: .fit)
						.contextMenu
					{
						Text("Test item")
						Text("Another item")
					}
				}
				.onCellEvent(onCellEvent)
				.sectionSupplementary(ofKind: MagazineLayout.SupplementaryViewKind.sectionHeader)
				{
					HStack
					{
						Text("Section \(offset)")
							.padding()
						Spacer()
					}
					.background(Color.blue)
				}
			}
		}
	}

	var body: some View
	{
		ASCollectionView(sections: self.sections)
			.layout { MagazineLayout() }
			.customDelegate(ASCollectionViewMagazineLayoutDelegate.init)
			.edgesIgnoringSafeArea(.all)
			.navigationBarTitle("Magazine Layout (custom delegate)", displayMode: .inline)
			.onCollectionViewReachedBoundary
		{ boundary in
			print("Reached the \(boundary) boundary")
		}
	}

	func onCellEvent(_ event: CellEvent<Post>)
	{
		switch event
		{
		case let .onAppear(item):
			ASRemoteImageManager.shared.load(item.url)
		case let .onDisappear(item):
			ASRemoteImageManager.shared.cancelLoad(for: item.url)
		case let .prefetchForData(data):
			for item in data
			{
				ASRemoteImageManager.shared.load(item.url)
			}
		case let .cancelPrefetchForData(data):
			for item in data
			{
				ASRemoteImageManager.shared.cancelLoad(for: item.url)
			}
		}
	}
}

struct MagazineLayoutScreen_Previews: PreviewProvider
{
	static var previews: some View
	{
		MagazineLayoutScreen()
	}
}
