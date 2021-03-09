// Copyright © Vitya Poekhal
// https://youtube.com/channel/UC57HY7GHQZrTS4PY5uOroaA
// https://instagram.com/vityapoekhal
// https://habr.com/en/users/vityapoekhal

import WidgetKit
import SwiftUI

// MARK: - View

struct StackoverflowBountyWidgetView: View {
    private let gradient = Gradient(colors: [.red, .orange, .yellow, .orange, .purple, .pink])
    private let defaultIconName = "person.circle"

    let entry: StackoverflowBountyEntry

    var body: some View {
        if let title = entry.firstItem?.title,
           let name = entry.firstItem?.owner?.display_name {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 4) {
                    (entry.image.map { Image(uiImage: $0) } ?? Image(systemName: defaultIconName))
                        .resizable()
                        .frame(width: 14, height: 14)
                        .clipShape(Circle())
                    Text(name)
                        .lineLimit(1)
                        .font(.system(.callout))
                        .foregroundColor(.black)
                }
                Text(title)
                    .lineLimit(3)
                    .font(.system(.title3))
                    .foregroundColor(.black)
                    .padding(.bottom, 2)
                HStack {
                    ForEach(entry.firstItem?.tags ?? [], id: \.self) { tag in
                        Text(tag)
                            .foregroundColor(.black)
                            .font(.system(.footnote))
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(AngularGradient(gradient: gradient, center: .topTrailing)))
                            .fixedSize(horizontal: true, vertical: true)
                    }
                }
            }
            .frame(minWidth: .zero, maxWidth: .infinity, minHeight: .zero, maxHeight: .infinity, alignment: .leading)
            .padding()
            .background(AngularGradient(gradient: gradient, center: .bottomLeading))
        } else {
            Text("Can't find any questions with \(entry.items?.requestedTags?.joined(separator: " ") ?? "no") tags")
                .multilineTextAlignment(.center)
                .frame(minWidth: .zero, maxWidth: .infinity, minHeight: .zero, maxHeight: .infinity, alignment: .center)
                .background(AngularGradient(gradient: gradient, center: .bottomLeading))
        }
    }
}

struct MainWidget_Previews: PreviewProvider {
    static var previews: some View {
        StackoverflowBountyWidgetView(
            entry: StackoverflowBountyEntry(date: Date(), items: placeholderItems)
        ).previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}

// MARK: - Model

let placeholderItems = StackoverflowBountyItems(items: [
    StackoverflowBountyItem(
        tags: ["Hypothetical Personal Situations", "Personal Question"],
        owner: StackoverflowBountyItemOwner(profile_image: nil, display_name: "Anonymous"),
        link: nil,
        title: "If I ate myself, would I become twice as big or disappear completely?")
])

struct StackoverflowBountyItems: Codable {
    let items: [StackoverflowBountyItem]
    var firstItem: StackoverflowBountyItem? { items.first }
    var requestedTags: [String]? = nil

    var isNotEmpty: Bool { firstItem != nil }
}

struct StackoverflowBountyItem: Codable {
    let tags: [String]?
    let owner: StackoverflowBountyItemOwner?
    let link: String?
    let title: String?
}

struct StackoverflowBountyItemOwner: Codable {
    let profile_image: String?
    let display_name: String?
}

// MARK: - Loader

enum StackoverflowBountyLoader {
    enum LoaderError: Error {
        case unknown
    }

    private static let cacheKey = "StackoverflowBountyItems"

    static func fetchItems(
        with tags: [String] = [],
        completion: @escaping (Result<StackoverflowBountyItems, Error>) -> Void
    ) {
        guard let url = URL(
            string: """
                https://api.stackexchange.com/2.2/questions/featured\
                ?page=1&pagesize=1&order=desc&sort=activity\
                &tagged=\(tags.joined(separator: ";"))&site=stackoverflow
                """
        ) else { return }

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                if let error = error { completion(.failure(error)) }
                return
            }
            do {
                var items = try JSONDecoder().decode(StackoverflowBountyItems.self, from: data)
                items.requestedTags = tags
                saveCache(items: items)
                DispatchQueue.main.async { completion(.success(items)) }
                return
            } catch {
                completion(.failure(error))
                return
            }
        }
        task.resume()
    }

    static func fetchImage(with url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                if let error = error { completion(.failure(error)) }
                else { completion(.failure(LoaderError.unknown)) }
                return
            }
            if let image = UIImage(data: data) {
                DispatchQueue.main.async { completion(.success(image)) }
                return
            }
            completion(.failure(LoaderError.unknown))
        }
        task.resume()
    }

    static func saveCache(items: StackoverflowBountyItems) {
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: cacheKey)
    }

    static func loadCache() -> StackoverflowBountyItems? {
        return (UserDefaults.standard.object(forKey: cacheKey) as? Data)
            .flatMap { try? JSONDecoder().decode(StackoverflowBountyItems.self, from: $0) }
    }
}

