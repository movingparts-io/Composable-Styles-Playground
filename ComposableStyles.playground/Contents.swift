import SwiftUI
import PlaygroundSupport

// MARK: Component

struct LabelGroup<Label: View, Content: View>: View {
    var label: Label

    var content: Content

    @Environment(\.labelGroupStyle)
    var style

    init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content()
        self.label = label()
    }

    var body: some View {
        let configuration = LabelGroupStyleConfiguration(content: .init(content), label: .init(label))
        AnyView(style.resolve(configuration: configuration))
            .transformEnvironment(\.labelGroupStyleStack) { styles in
                if styles.isEmpty { return }
                styles.removeLast()
            }
    }
}

extension LabelGroup where Label == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        self.label = EmptyView()
    }
}

// MARK: - Style Configuration Initializer

extension LabelGroup where Content == LabelGroupStyleConfiguration.Content, Label == LabelGroupStyleConfiguration.Label {
    init(_ configuration: LabelGroupStyleConfiguration) {
        self.content = configuration.content
        self.label = configuration.label
    }
}

// MARK: - Resolve Style

struct ResolvedLabelGroupStyle<Style: LabelGroupStyle>: View {
    var configuration: LabelGroupStyleConfiguration

    var style: Style

    var body: some View {
        style.makeBody(configuration: configuration)
    }
}

extension LabelGroupStyle {
    func resolve(configuration: Configuration) -> some View {
        ResolvedLabelGroupStyle(configuration: configuration, style: self)
    }
}

// MARK: - Style Protocol

protocol LabelGroupStyle: DynamicProperty {
    associatedtype Body: View

    @ViewBuilder func makeBody(configuration: Configuration) -> Body

    typealias Configuration = LabelGroupStyleConfiguration
}

// MARK: - Style Configuration

struct LabelGroupStyleConfiguration {
    struct Content: View {
        var underlyingView: AnyView

        init(_ view: some View) {
            self.underlyingView = AnyView(view)
        }

        var body: some View {
            underlyingView
        }
    }

    var content: Content

    struct Label: View {
        var underlyingView: AnyView

        init(_ view: some View) {
            self.underlyingView = AnyView(view)
        }

        var body: some View {
            underlyingView
        }
    }

    var label: Label
}

// MARK: - Environment

private struct LabelGroupStyleStackKey: EnvironmentKey {
    static var defaultValue: [any LabelGroupStyle] = []
}

extension EnvironmentValues {
    var labelGroupStyleStack: [any LabelGroupStyle] {
        get { self[LabelGroupStyleStackKey.self] }
        set { self[LabelGroupStyleStackKey.self] = newValue }
    }

    var labelGroupStyle: any LabelGroupStyle {
        labelGroupStyleStack.last ?? PlainLabelGroupStyle()
    }
}

extension View {
    func labelGroupStyle(_ style: some LabelGroupStyle) -> some View {
        transformEnvironment(\.labelGroupStyleStack) { styles in
            styles.append(style)
        }
    }
}

// MARK: - Styles

struct PlainLabelGroupStyle: LabelGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.label
            configuration.content
        }
    }
}

extension LabelGroupStyle where Self == PlainLabelGroupStyle {
    static var plain: Self { .init() }
}

struct ListLabelGroupStyle: LabelGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .trailing) {
            Divided {
                configuration.label.bold()
                configuration.content
            }
        }
    }
}

extension LabelGroupStyle where Self == ListLabelGroupStyle {
    static var list: Self { .init() }
}

// MARK: - Style Modifier

struct ModifiedStyle<Style, Modifier: ViewModifier>: DynamicProperty {
    var style: Style
    var modifier: Modifier
}

extension ModifiedStyle: LabelGroupStyle where Style: LabelGroupStyle {
    func makeBody(configuration: LabelGroupStyleConfiguration) -> some View {
        LabelGroup(configuration)
            .labelGroupStyle(style)
            .modifier(modifier)
    }
}

extension LabelGroupStyle {
    func modifier(_ modifier: some ViewModifier) -> some LabelGroupStyle {
        ModifiedStyle(style: self, modifier: modifier)
    }
}

// MARK: - Label Group Style Modifiers

struct CardBackdropModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background {
                ContainerRelativeShape()
                    .fill(.background.shadow(.inner(color: .white.opacity(0.75), radius: 0.25, y: 0.5)))
                    .shadow(radius: 10, x: 0, y: 5)
            }
    }
}

extension LabelGroupStyle {
    var card: some LabelGroupStyle {
        modifier(CardBackdropModifier())
    }
}

struct BackgroundStyleModifier<Style: ShapeStyle>: ViewModifier {
    var style: Style

    func body(content: Content) -> some View {
        content.backgroundStyle(style)
    }
}

extension LabelGroupStyle {
    func backgroundStyle(_ style: some ShapeStyle) -> some LabelGroupStyle {
        modifier(BackgroundStyleModifier(style: style))
    }
}

struct FontModifier: ViewModifier {
    var font: Font

    func body(content: Content) -> some View {
        content.font(font)
    }
}

extension LabelGroupStyle {
    func font(_ font: Font) -> some LabelGroupStyle {
        modifier(FontModifier(font: font))
    }
}

struct LabelStyleModifier<Style: LabelStyle>: ViewModifier {
    var style: Style

    func body(content: Content) -> some View {
        content.labelStyle(style)
    }
}

extension LabelGroupStyle {
    func labelStyle(_ style: some LabelStyle) -> some LabelGroupStyle {
        modifier(LabelStyleModifier(style: style))
    }
}

struct TrailingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            Spacer()
            configuration.icon
        }
    }
}

extension LabelStyle where Self == TrailingLabelStyle {
    static var trailing: Self { .init() }
}

// MARK: - Divided

struct Divided<Content: View>: View {
    private struct DividedLayout: _VariadicView_MultiViewRoot {
        @ViewBuilder
        func body(children: _VariadicView.Children) -> some View {
            let last = children.last?.id

            ForEach(children) { child in
                child

                if child.id != last {
                    Divider()
                }
            }
        }
    }

    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        _VariadicView.Tree(DividedLayout()) {
            content
        }
    }
}

// MARK: - Composed & Reapplying Style

struct ComposedLabelGroupStyle: LabelGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        ListLabelGroupStyle()
            .card
            .labelStyle(.trailing)
            .font(.system(.footnote, design: .monospaced))
            .backgroundStyle(Color(white: 0.95))
            .makeBody(configuration: configuration)
            .labelGroupStyle(self)
    }
}

extension LabelGroupStyle where Self == ComposedLabelGroupStyle {
    static var composed: ComposedLabelGroupStyle { .init() }
}

// MARK: - Example View

struct ContentView: View {
    struct Coffee: Identifiable {
        var id: String { name }
        var name: String
        var origin: String
        var region: String
        var altitude: Measurement<UnitLength>
        var tasteNotes: [String]
        var year: DateComponents
    }

    let coffee = Coffee(
        name: "Kaffe No 3",
        origin: "El Salvador",
        region: "Ahuachapán",
        altitude: Measurement<UnitLength>(value: 1700, unit: .meters),
        tasteNotes: ["Orange", "Butterscotch", "Red Grape"],
        year: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2016)
    )

    var body: some View {
        LabelGroup {
            LabeledContent("Origin", value: coffee.origin)
            LabeledContent("Region", value: coffee.region)
            LabeledContent("Altitude", value: coffee.altitude, format: .measurement(width: .narrow, usage: .asProvided))
            LabeledContent("Year", value: coffee.year.date!, format: .dateTime.year())
            LabelGroup {
                ForEach(coffee.tasteNotes, id: \.self) { note in
                    Text(note)
                }
            } label: {
                Label("Taste Notes", systemImage: "music.quarternote.3")
            }
        } label: {
            Label(coffee.name, systemImage: "cup.and.saucer")
        }
        .labelGroupStyle(.composed)
        .containerShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(width: 240)
        .padding()
    }
}

PlaygroundPage.current.setLiveView(ContentView())
