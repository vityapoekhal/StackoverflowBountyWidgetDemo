// Copyright © Vitya Poekhal
// https://youtube.com/channel/UC57HY7GHQZrTS4PY5uOroaA
// https://instagram.com/vityapoekhal
// https://habr.com/en/users/vityapoekhal

import WidgetKit
import SwiftUI
import Intents

// MARK: - WidgetBundle

@main
struct SwiftWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        StackoverflowBountyWidget()
    }
}

// MARK: - Widget

//@main
struct StackoverflowBountyWidget: Widget {
    public var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: String(describing: Self.self),
            intent: QuestionTagsIntent.self,
            provider: StackoverflowBountyTimeline()
        ) { entry in
            StackoverflowBountyWidgetView(entry: entry)
        }
        .configurationDisplayName("Stackoverflow Bounty Configurable")
        .description("Shows the stackoverflow's bounty questions")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - TimelineProvider

struct StackoverflowBountyTimeline: IntentTimelineProvider {
    typealias Entry = StackoverflowBountyEntry
    typealias Intent = QuestionTagsIntent

    private let placeholderEntry = StackoverflowBountyEntry(date: Date(), items: placeholderItems)

    func placeholder(in context: Context) -> StackoverflowBountyEntry {
        return placeholderEntry
    }

    func getSnapshot(for configuration: QuestionTagsIntent, in context: Context, completion: @escaping (StackoverflowBountyEntry) -> Void) {
        guard let cache = StackoverflowBountyLoader.loadCache(), cache.isNotEmpty, cache.requestedTags == configuration.tags else {
            completion(placeholderEntry)
            return
        }

        if context.isPreview {
            let entry = StackoverflowBountyEntry(date: Date(), items: cache)
            completion(entry)
        } else  {
            loadImage(items: cache) { image in
                let entry = StackoverflowBountyEntry(date: Date(), items: cache, image: image)
                completion(entry)
            }
        }
    }

    func getTimeline(for configuration: QuestionTagsIntent, in context: Context, completion: @escaping (Timeline<StackoverflowBountyEntry>) -> Void) {
        StackoverflowBountyLoader.fetchItems(with: configuration.tags ?? []) { result in
            switch result {
            case .success(let items):
                self.loadImage(items: items) { completion(makeTimeline(items: items, image: $0)) }
            case .failure(let error):
                print(error)
            }
        }
    }

    // MARK: - TimelineProvider Helpers

    private func makeTimeline(items: StackoverflowBountyItems, image: UIImage?) -> Timeline<StackoverflowBountyEntry> {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
        let entry = StackoverflowBountyEntry(date: currentDate, items: items, image: image)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func loadImage(items: StackoverflowBountyItems, completion: @escaping (UIImage?) -> Void) {
        guard let imageURLString = items.firstItem?.owner?.profile_image, let url = URL(string: imageURLString) else {
            completion(nil)
            return
        }
        StackoverflowBountyLoader.fetchImage(with: url) { result in
            switch result {
            case .success(let image): completion(image)
            case .failure(let error): print(error)
            }
        }
    }
}

// MARK: - TimelineEntry

struct StackoverflowBountyEntry: TimelineEntry {
    let date: Date
    let items: StackoverflowBountyItems?
    var firstItem: StackoverflowBountyItem? { items?.firstItem }
    var image: UIImage? = nil
}
