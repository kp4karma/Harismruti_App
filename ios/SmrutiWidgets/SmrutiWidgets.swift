import SwiftUI
import WidgetKit

private let appGroup = "group.org.hp.harismruti.widgets"

private extension View {
  @ViewBuilder
  func smrutiWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) {
        Color(red: 0.98, green: 0.95, blue: 0.93)
      }
    } else {
      background(Color(red: 0.98, green: 0.95, blue: 0.93))
    }
  }
}

private struct SmrutiStory: Decodable, Identifiable {
  let image: String
  let title: String
  let uri: String
  var id: String { uri + image }
}

private struct SmrutiEntry: TimelineEntry {
  let date: Date
  let kind: String
  let stories: [SmrutiStory]
}

private struct SmrutiProvider: TimelineProvider {
  let kind: String

  func placeholder(in context: Context) -> SmrutiEntry {
    SmrutiEntry(date: Date(), kind: kind, stories: [])
  }

  func getSnapshot(in context: Context, completion: @escaping (SmrutiEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SmrutiEntry>) -> Void) {
    let entry = loadEntry()
    let defaults = UserDefaults(suiteName: appGroup)
    let hours = max(defaults?.integer(forKey: "smruti_refresh_hours") ?? 1, 1)
    let next = Calendar.current.date(byAdding: .hour, value: hours, to: Date()) ?? Date().addingTimeInterval(3600)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }

  private func loadEntry() -> SmrutiEntry {
    let defaults = UserDefaults(suiteName: appGroup)
    let raw = defaults?.string(forKey: "smruti_stories_\(kind)") ?? "[]"
    let stories = (try? JSONDecoder().decode([SmrutiStory].self, from: Data(raw.utf8))) ?? []
    return SmrutiEntry(date: Date(), kind: kind, stories: stories)
  }
}

private struct StoryImage: View {
  let story: SmrutiStory?
  let rounded: CGFloat

  var body: some View {
    Group {
      if let story, let image = UIImage(contentsOfFile: story.image) {
        Image(uiImage: image).resizable().scaledToFill()
      } else {
        ZStack {
          LinearGradient(colors: [Color(red: 0.45, green: 0.12, blue: 0.10), Color(red: 0.18, green: 0.06, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
          Image(systemName: "photo.on.rectangle.angled").foregroundStyle(.white.opacity(0.8))
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: rounded, style: .continuous))
  }
}

private struct SmrutiWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SmrutiEntry

  private func story(_ index: Int) -> SmrutiStory? {
    entry.stories.isEmpty ? nil : entry.stories[index % entry.stories.count]
  }

  var body: some View {
    Group {
      switch entry.kind {
      case "DailyDarshanWidgetProvider": daily
      case "SmrutiStoriesWidgetProvider": stories
      case "FeaturedRecentWidgetProvider": featured
      case "MinimalSmrutiWidgetProvider": minimal
      default: grid
      }
    }
    .widgetURL(URL(string: story(0)?.uri ?? "harismruti://home"))
    .smrutiWidgetBackground()
  }

  private var grid: some View {
    GeometryReader { proxy in
      let gap: CGFloat = 3
      VStack(spacing: gap) {
        HStack(spacing: gap) {
          StoryImage(story: story(0), rounded: 9)
          StoryImage(story: story(1), rounded: 9)
        }
        HStack(spacing: gap) {
          StoryImage(story: story(2), rounded: 9)
          StoryImage(story: story(3), rounded: 9)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }

  private var daily: some View {
    ZStack(alignment: .bottomLeading) {
      StoryImage(story: story(0), rounded: 0)
      LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
      VStack(alignment: .leading, spacing: 2) {
        Text("Daily Darshan").font(.headline).bold()
        Text(story(0)?.title ?? "Today’s Smruti").font(.caption).lineLimit(1)
      }
      .foregroundStyle(.white).padding(12)
    }
  }

  private var stories: some View {
    HStack(spacing: 5) {
      ForEach(0..<4, id: \.self) { index in
        VStack(spacing: 5) {
          StoryImage(story: story(index), rounded: 50)
            .overlay(Circle().stroke(Color(red: 0.55, green: 0.13, blue: 0.11), lineWidth: 2))
          Text(story(index)?.title ?? "Smruti").font(.system(size: 9, weight: .semibold)).lineLimit(1)
        }
      }
    }.padding(8)
  }

  private var featured: some View {
    HStack(spacing: 4) {
      StoryImage(story: story(0), rounded: 12).frame(maxWidth: .infinity)
      VStack(spacing: 4) {
        StoryImage(story: story(1), rounded: 9)
        StoryImage(story: story(2), rounded: 9)
      }.frame(maxWidth: .infinity)
    }.padding(4)
  }

  private var minimal: some View {
    HStack(spacing: 12) {
      StoryImage(story: story(0), rounded: 12).frame(width: 82)
      VStack(alignment: .leading, spacing: 6) {
        Text("HariPrabodham Smruti").font(.headline).bold().lineLimit(2)
        Text(story(0)?.title ?? "Your daily Smruti").font(.caption).foregroundStyle(.secondary).lineLimit(2)
        Text(entry.date, style: .date).font(.caption2).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }.padding(10)
  }
}

private struct SmrutiWidget: Widget {
  let kind: String
  let name: String
  let description: String
  let families: [WidgetFamily]

  init(kind: String, name: String, description: String, families: [WidgetFamily]) {
    self.kind = kind
    self.name = name
    self.description = description
    self.families = families
  }

  init() {
    self.init(kind: "SmrutiHomeWidgetProvider", name: "", description: "", families: [.systemSmall])
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SmrutiProvider(kind: kind)) { entry in
      SmrutiWidgetView(entry: entry)
    }
    .configurationDisplayName(name)
    .description(description)
    .supportedFamilies(families)
  }
}

@main
struct SmrutiWidgetsBundle: WidgetBundle {
  var body: some Widget {
    SmrutiWidget(kind: "SmrutiHomeWidgetProvider", name: "Photo Grid", description: "A responsive gallery of recent Smrutis.", families: [.systemSmall, .systemMedium, .systemLarge])
    SmrutiWidget(kind: "DailyDarshanWidgetProvider", name: "Daily Darshan", description: "One peaceful daily Darshan photo.", families: [.systemSmall, .systemMedium])
    SmrutiWidget(kind: "SmrutiStoriesWidgetProvider", name: "Smruti Stories", description: "Quick story-style memories.", families: [.systemMedium])
    SmrutiWidget(kind: "FeaturedRecentWidgetProvider", name: "Featured + Recent", description: "One featured photo with recent moments.", families: [.systemMedium, .systemLarge])
    SmrutiWidget(kind: "MinimalSmrutiWidgetProvider", name: "Minimal Smruti", description: "A compact photo, title and date.", families: [.systemMedium])
  }
}
