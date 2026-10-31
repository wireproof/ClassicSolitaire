import SwiftUI
import Combine
import AVFoundation
import SolitaireEngine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@main struct ClassicSolitaireApp: App { var body: some Scene { WindowGroup { GameView() } } }
struct Selection: Equatable { let pile: Pile; let index: Int }
struct Snapshot: Codable { var game: Game; var score: Int; var seconds: Int }
struct SavedSession: Codable { var current: Snapshot; var undo: [Snapshot] }

@MainActor final class SoundEffects {
    static let shared = SoundEffects()
    private var players: [AVAudioPlayer] = []
    func play(_ name: String) {
        guard UserDefaults.standard.bool(forKey: "soundEnabled"), UserDefaults.standard.bool(forKey: "vistaAppearance"),
              let url = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Sounds"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        players.removeAll { !$0.isPlaying }
        players.append(player)
        player.play()
    }
}

@MainActor final class GameSession: ObservableObject {
    @Published var game: Game
    @Published var score: Int
    @Published var seconds: Int
    @Published var selection: Selection?
    @Published var hintText = ""
    private var history: [Snapshot]
    private let key = "classicSolitaireSessionV1"
    init() {
        if let data = UserDefaults.standard.data(forKey: key), let saved = try? JSONDecoder().decode(SavedSession.self, from: data), saved.current.game.isValid {
            game = saved.current.game; score = saved.current.score; seconds = saved.current.seconds; history = saved.undo.filter { $0.game.isValid }
        } else { game = Game(); score = 0; seconds = 0; history = [] }
    }
    var canUndo: Bool { !history.isEmpty }
    private var snapshot: Snapshot { Snapshot(game: game, score: score, seconds: seconds) }
    func save() { if let data = try? JSONEncoder().encode(SavedSession(current: snapshot, undo: history)) { UserDefaults.standard.set(data, forKey: key) } }
    func tick() { if !game.won { seconds += 1; if seconds % 10 == 0 { save() } } }
    func newGame(drawCount: Int) { game = Game(drawCount: drawCount); score = 0; seconds = 0; history = []; selection = nil; hintText = ""; save() }
    func setDraw(_ count: Int) { game.drawCount = count; selection = nil; save() }
    func draw() { guard !game.stock.isEmpty || !game.waste.isEmpty else { return }; history.append(snapshot); game.draw(); SoundEffects.shared.play("SHARED_CARDDEAL"); selection = nil; hintText = ""; save() }
    func undo() { guard let old = history.popLast() else { return }; game = old.game; score = old.score; seconds = old.seconds; SoundEffects.shared.play("SHARED_UNDO"); selection = nil; hintText = ""; save() }
    func choose(_ pile: Pile, index: Int?) {
        if let selected = selection {
            let old = snapshot; let faceDown = { if case .tableau(let i) = selected.pile { return game.tableau[i].filter { !$0.faceUp }.count }; return 0 }()
            if game.move(from: selected.pile, index: selected.index, to: pile) {
                history.append(old)
                if case .foundation = pile { SoundEffects.shared.play("SHARED_MOVETOHOME") } else { SoundEffects.shared.play("SHARED_MOVECARDSETDOWN") }
                switch (selected.pile, pile) { case (.waste, .foundation), (.tableau, .foundation): score += 10; case (.waste, .tableau): score += 5; case (.foundation, .tableau): score = max(0, score - 15); default: break }
                if case .tableau(let i) = selected.pile, game.tableau[i].filter({ !$0.faceUp }).count < faceDown { score += 5 }
                selection = nil; hintText = ""; save(); return
            }
            if selected.pile == pile && selected.index == index { selection = nil; return }
        }
        guard let index, game.cards(in: pile).indices.contains(index), game.cards(in: pile)[index].faceUp else { selection = nil; return }
        selection = Selection(pile: pile, index: index); hintText = ""
    }
    func autoHome() {
        var moved = true
        while moved {
            moved = false
            for source in [Pile.waste] + (0..<7).map(Pile.tableau) {
                guard let index = game.cards(in: source).indices.last else { continue }
                for destination in 0..<4 {
                    var probe = game
                    if probe.move(from: source, index: index, to: .foundation(destination)) {
                        selection = Selection(pile: source, index: index)
                        choose(.foundation(destination), index: nil)
                        moved = true
                        break
                    }
                }
                if moved { break }
            }
        }
        selection = nil
    }
    func hint() {
        for source in [Pile.waste] + (0..<7).map(Pile.tableau) {
            let cards = game.cards(in: source)
            for index in cards.indices where cards[index].faceUp {
                for target in (0..<4).map(Pile.foundation) + (0..<7).map(Pile.tableau) {
                    var copy = game
                    if copy.move(from: source, index: index, to: target) {
                        selection = Selection(pile: source, index: index)
                        let destination: String
                        switch target { case .foundation(let i): destination = "foundation \(i + 1)"; case .tableau(let i): destination = "column \(i + 1)"; case .waste: destination = "waste" }
                        hintText = "Move \(cards[index].label) to \(destination)."; SoundEffects.shared.play("SHARED_HINTSHOWN"); return
                    }
                }
            }
        }
        selection = nil; hintText = game.stock.isEmpty && game.waste.isEmpty ? "No moves found." : "Try drawing from the stock."; SoundEffects.shared.play("SHARED_HINTNOMOVE")
    }
}
struct GameView: View {
    @StateObject private var session = GameSession()
    @AppStorage("vistaAppearance") private var vistaAppearance = false
    @AppStorage("legacyAppearance") private var legacyAppearance = false
    @AppStorage("legacyBack") private var legacyBack = 64
    @AppStorage("legacyRemastered") private var legacyRemastered = false
    @AppStorage("soundEnabled") private var soundEnabled = false
    @State private var showSettings = false
    @State private var nativeSidebar = false
    @State private var nativeBarLeading = false
    @State private var widePortrait = false
    @State private var hingeOpen = false
    @State private var controlsExpanded = false
    @State private var confirmNew = false
    @State private var previewVictory = false
    @State private var dismissedVictory = false
    @AppStorage("vistaBackground") private var vistaBackground = "FELT"
    @AppStorage("xpBack") private var xpBack = 54
    @AppStorage("xpRemastered") private var xpRemastered = false
    @AppStorage("vistaBack") private var vistaBack = 0
    @AppStorage("vistaDeck") private var vistaDeck = "VistaCards"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack {
        tableBackground
        NavigationStack {
        GeometryReader { geometry in
            let coverSide = nativeSidebar || (geometry.safeAreaInsets.trailing > 40 && geometry.size.height > geometry.size.width)
            let landscape = geometry.size.width > geometry.size.height
            let useNativeControls = coverSide || hingeOpen || (!landscape && geometry.size.width >= 500)
            let boardWidth = max(140, geometry.size.width - 16)
            let widthBasedCard = max(16, (boardWidth - 18) / 7)
            let heightBasedCard = max(24, (geometry.size.height - 72) / (2 * 96 / 71 + 0.85))
            let cardWidth = min(110, widthBasedCard, landscape ? heightBasedCard : 110)
            let cardHeight = cardWidth * 96 / 71
            let maxCards = session.game.tableau.map(\.count).max() ?? 1
            let stackSpace = max(0, geometry.size.height - cardHeight * 2 - (useNativeControls ? 30 : 70))
            let step = min(cardWidth * 0.30, max(6, stackSpace / CGFloat(max(1, maxCards - 1))))
            ZStack(alignment: .bottomLeading) {
                gameBoard(width: cardWidth, height: cardHeight, step: step, showReadout: !useNativeControls && !landscape)
                    .frame(width: boardWidth, height: geometry.size.height - 16, alignment: .topLeading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                if landscape && !coverSide {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Score: \(session.score)")
                        Text(String(format: "Time: %d:%02d", session.seconds / 60, session.seconds % 60))
                    }
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 10)
                    .padding(.bottom, max(12, geometry.safeAreaInsets.bottom))
                }
                if nativeSidebar {
                    VStack(spacing: 5) {
                        sidebarReadout("SCORE", value: "\(session.score)")
                        sidebarReadout("TIME", value: String(format: "%d:%02d", session.seconds / 60, session.seconds % 60))
                    }
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: nativeBarLeading ? .bottomLeading : .bottomTrailing)
                    .offset(x: nativeBarLeading ? -max(0, geometry.safeAreaInsets.leading - 48) : max(0, geometry.safeAreaInsets.trailing - 48))
                    .padding(.bottom, max(16, geometry.safeAreaInsets.bottom))
                }
                if !useNativeControls {
                    floatingControls
                        .padding(.leading, 8)
                        .padding(.bottom, max(12, geometry.safeAreaInsets.bottom))
                }
            }
            .padding(.top, 8)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .onAppear { widePortrait = !landscape && geometry.size.width >= 500 }
            .onChange(of: !landscape && geometry.size.width >= 500) { widePortrait = $0 }
            .background {
                if #available(iOS 27.1, *) {
                    VerticalBarObserver(isActive: $nativeSidebar, isLeading: $nativeBarLeading)
                    #if canImport(UIKit)
                    HingeObserver(isOpen: $hingeOpen)
                    #endif
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background { tableBackground }
        .toolbar((nativeSidebar || widePortrait || hingeOpen) ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { controlsExpanded.toggle() } } label: {
                    Label(controlsExpanded ? "Close game controls" : "Open game controls", systemImage: controlsExpanded ? "xmark" : "line.3.horizontal")
                }
                if controlsExpanded {
                    Button { controlsExpanded = false; confirmNew = true } label: { Label("New game", systemImage: "plus") }
                    Button { session.undo(); controlsExpanded = false } label: { Label("Undo", systemImage: "arrow.uturn.backward") }.disabled(!session.canUndo)
                    Button { session.hint(); controlsExpanded = false } label: { Label("Hint", systemImage: "lightbulb") }
                    Button { session.autoHome(); controlsExpanded = false } label: { Label("Move to foundations", systemImage: "arrow.up.to.line") }
                    Button { controlsExpanded = false; showSettings = true } label: { Label("Game options", systemImage: "gearshape") }
                }
            }
            if #available(iOS 27.1, *), widePortrait && !nativeSidebar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    readoutCircle("SCORE", value: "\(session.score)")
                }.axisBehavior(.verticalPreferred).visibilityPriority(.high)
                ToolbarItem(placement: .navigationBarTrailing) {
                    readoutCircle("TIME", value: String(format: "%d:%02d", session.seconds / 60, session.seconds % 60))
                }.axisBehavior(.verticalPreferred).visibilityPriority(.high)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(.clear)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(.clear)
        }
        .overlay {
            if previewVictory || (session.game.won && !dismissedVictory) {
                VictoryView(reducedMotion: reduceMotion, vista: vistaAppearance, deck: vistaDeck, close: { previewVictory = false; dismissedVictory = true })
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(drawCount: session.game.drawCount, setDraw: { session.setDraw($0) }, preview: { previewVictory = true })
        }
        .alert("Start a new game?", isPresented: $confirmNew) {
            Button("Cancel", role: .cancel) { }
            Button("New Game", role: .destructive) { session.newGame(drawCount: session.game.drawCount) }
        } message: { Text("Your current game will be replaced.") }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: session.game.stock.count)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: session.game.foundations.map(\.count))
        .onChange(of: session.game.won) { won in if !won { dismissedVictory = false } else { SoundEffects.shared.play("SHARED_CARDFALLING") } }
        .onReceive(timer) { _ in if scenePhase == .active && !showSettings && !confirmNew { session.tick() } }
        .onChange(of: scenePhase) { phase in if phase != .active { session.save() } }
    }
    private func sidebarReadout(_ label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 8, weight: .bold))
            Text(value).font(.system(size: 11, weight: .semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.65)
        }
        .foregroundStyle(.white)
        .frame(width: 42, height: 42)
        .background(Color.black.opacity(0.48), in: Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
    private func readoutCircle(_ label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 8, weight: .bold))
            Text(value).font(.system(size: 11, weight: .semibold).monospacedDigit()).minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(width: 44, height: 44)
        .background(.primary.opacity(0.12), in: Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
    private var tableBackground: some View {
        GeometryReader { area in
            if vistaAppearance {
                asset(vistaBackground, ext: "JPG", subdirectory: "Backgrounds")
                    .resizable().scaledToFill().frame(width: area.size.width, height: area.size.height + 120, alignment: .top).clipped()
            } else { Color(red: 0, green: 0.42, blue: 0.25) }
        }.ignoresSafeArea()
    }
    @ViewBuilder
    func gameBoard(width: CGFloat, height: CGFloat, step: CGFloat, showReadout: Bool) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 3) {
                    Button { session.draw() } label: { cardFace(session.game.stock.last, width: width, height: height, placeholder: "↻") }
                        .buttonStyle(.plain).accessibilityLabel(session.game.stock.isEmpty ? "Recycle waste" : "Draw cards")
                    pileView(.waste, width: width, height: height)
                    Spacer(minLength: 0)
                    ForEach(0..<4) { pileView(.foundation($0), width: width, height: height) }
                }
                HStack(alignment: .top, spacing: 3) {
                    ForEach(0..<7) { column in
                        let pile = Pile.tableau(column); let cards = session.game.tableau[column]
                        ZStack(alignment: .top) {
                            Button { session.choose(pile, index: nil) } label: { cardFace(nil, width: width, height: height, placeholder: "K") }.buttonStyle(.plain)
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                Button { session.choose(pile, index: index) } label: { cardFace(card, width: width, height: height, selected: session.selection == Selection(pile: pile, index: index)) }
                                    .buttonStyle(.plain).offset(y: CGFloat(index) * step)
                            }
                        }.frame(width: width, height: height + CGFloat(max(0, cards.count - 1)) * step, alignment: .top)
                    }
                }
                if showReadout {
                    HStack { Text("Score: \(session.score)"); Spacer(); Text(String(format: "Time: %d:%02d", session.seconds / 60, session.seconds % 60)) }
                        .font(.caption.monospacedDigit()).foregroundStyle(.white).padding(.top, 6)
                }
                if !session.hintText.isEmpty { Text(session.hintText).font(.caption).foregroundStyle(.white).padding(.top, 5) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.scrollIndicators(.visible)
    }
    private var floatingControls: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { controlsExpanded.toggle() }
            } label: { Image(systemName: controlsExpanded ? "xmark" : "line.3.horizontal").font(.system(size: 18, weight: .bold)) }
                .accessibilityLabel(controlsExpanded ? "Close game controls" : "Open game controls")
                .floatingControlStyle()
            if controlsExpanded {
                Button { controlsExpanded = false; confirmNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New game").floatingControlStyle()
                Button { session.undo(); controlsExpanded = false } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!session.canUndo).accessibilityLabel("Undo").floatingControlStyle()
                Button { session.hint(); controlsExpanded = false } label: { Image(systemName: "lightbulb") }
                    .accessibilityLabel("Hint").floatingControlStyle()
                Button { session.autoHome(); controlsExpanded = false } label: { Image(systemName: "arrow.up.to.line") }
                    .accessibilityLabel("Move to foundations").floatingControlStyle()
                Button { controlsExpanded = false; showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Game options").floatingControlStyle()
            }
        }
    }
    func legacyFrame(back: Int, date: Date) -> String {
        guard !reduceMotion else { return String(back) }
        let t = date.timeIntervalSinceReferenceDate
        switch back {
        case 63: return Int(t * 2) % 2 == 0 ? "63_0" : "63"
        case 64:
            let phase = t.truncatingRemainder(dividingBy: 30)
            return phase < 1.5 ? "64_\(Int(phase * 2) % 2)" : "64"
        case 65:
            let phase = t.truncatingRemainder(dividingBy: 15)
            return phase < 1.5 ? "65_\(Int(phase * 2) % 2)" : "65"
        case 56: return "56_\(Int(t * 2) % 2)"
        default: return String(back)
        }
    }
    func legacyBackName(_ number: Int) -> String {
        let names = ["Pattern 1", "Pattern 2", "Robot", "Roses", "Flowers (black)", "Flowers (blue)", "Fish", "Aquarium", "Shell", "Castle", "Palm Beach", "Card Hand"]
        return names[number - 54]
    }
    func xpBackName(_ number: Int) -> String {
        let names = ["Clouds", "Blue glass", "Fish", "Frog", "Rose", "Beach", "Blue tiles", "Purple lights", "Desert", "Astronaut", "Stripes", "Race cars"]
        return names[number - 54]
    }
    func pileView(_ pile: Pile, width: CGFloat, height: CGFloat) -> some View {
        let cards = session.game.cards(in: pile)
        return Button { session.choose(pile, index: cards.indices.last) } label: { cardFace(cards.last, width: width, height: height, selected: session.selection?.pile == pile, placeholder: "A") }.buttonStyle(.plain)
    }
    func asset(_ name: String, ext: String = "png", subdirectory: String? = nil) -> Image {
        let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: subdirectory)
        #if canImport(UIKit)
        if let path, let image = UIImage(contentsOfFile: path) { return Image(uiImage: image) }
        #elseif canImport(AppKit)
        if let path, let image = NSImage(contentsOfFile: path) { return Image(nsImage: image) }
        #endif
        return Image(systemName: "rectangle")
    }
    func cardFace(_ card: Card?, width: CGFloat, height: CGFloat, selected: Bool = false, placeholder: String = "") -> some View {
        ZStack(alignment: .topLeading) {
            if let card {
                let base: Int = switch card.suit { case .clubs: 0; case .diamonds: 13; case .hearts: 26; case .spades: 39 }
                if vistaAppearance {
                    asset(card.faceUp ? String(base + card.rank) : "back\(vistaBack)", subdirectory: card.faceUp ? vistaDeck : "VistaCards").resizable().interpolation(.high)
                } else if legacyAppearance {
                    if card.faceUp {
                        asset(String(base + card.rank), subdirectory: legacyRemastered ? "LegacyRemastered" : "LegacyCards").resizable().interpolation(legacyRemastered ? .high : .none)
                    } else {
                        TimelineView(.periodic(from: .now, by: 0.5)) { time in
                            let frame = legacyFrame(back: legacyBack, date: time.date)
                            if legacyRemastered && legacyBack == 64 {
                                GeometryReader { size in
                                    ZStack(alignment: .topLeading) {
                                        asset("64", subdirectory: "LegacyRemastered").resizable().interpolation(.high)
                                        if frame == "64_0" || frame == "64_1" {
                                            asset(frame == "64_0" ? "sun0" : "sun1", subdirectory: "LegacyRemastered")
                                                .resizable().interpolation(.none)
                                                .frame(width: size.size.width * 14 / 71, height: size.size.height * 12 / 96)
                                                .offset(x: size.size.width * 47 / 71, y: size.size.height / 96)
                                        }
                                    }
                                }
                            } else {
                                asset(frame, subdirectory: legacyRemastered ? "LegacyRemastered" : "LegacyCards").resizable().interpolation(legacyRemastered ? .high : .none)
                            }
                        }
                    }
                } else {
                    asset(String(card.faceUp ? base + card.rank : xpBack), subdirectory: xpRemastered ? "XPRemastered" : "Cards").resizable().interpolation(xpRemastered ? .high : .none)
                }
            } else {
                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.14))
                Text(placeholder).foregroundStyle(.white.opacity(0.5)).padding(4)
            }
            RoundedRectangle(cornerRadius: 4).stroke(selected ? Color.yellow : Color.black.opacity(0.25), lineWidth: selected ? 3 : 1)
        }.frame(width: width, height: height).accessibilityLabel(card.map { $0.faceUp ? $0.label : "Face down card" } ?? "Empty pile")
    }
}

struct VictoryView: View {
    let reducedMotion: Bool
    let vista: Bool
    let deck: String
    let close: () -> Void
    @State private var start = Date()
    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reducedMotion)) { context in
                let t = max(0, context.date.timeIntervalSince(start))
                Canvas { canvas, size in
                    for i in 0..<24 {
                        let delay = Double(i) * 0.12
                        let elapsed = max(0, t - delay)
                        let x = (Double(i % 4) + 1) * size.width / 5 + sin(elapsed * 1.3 + Double(i)) * size.width * 0.32
                        let y = reducedMotion ? size.height * 0.45 : (elapsed * 160 + Double(i * 53)).truncatingRemainder(dividingBy: size.height + 100) - 50
                        let rect = CGRect(x: x, y: y, width: 42, height: 57)
                        let name = String((i * 7) % 52 + 1)
                        if let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: vista ? deck : "Cards") {
                            #if canImport(UIKit)
                            if let image = UIImage(contentsOfFile: path) { canvas.draw(Image(uiImage: image), in: rect) }
                            #elseif canImport(AppKit)
                            if let image = NSImage(contentsOfFile: path) { canvas.draw(Image(nsImage: image), in: rect) }
                            #endif
                        }
                    }
                }
            }.allowsHitTesting(false)
            VStack { Text("You win!").font(.largeTitle.bold()).foregroundStyle(.white).shadow(radius: 4); Button("Close") { close() }.buttonStyle(.borderedProminent) }
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.34)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("vistaAppearance") private var vista = false
    @AppStorage("legacyAppearance") private var legacy = false
    @AppStorage("legacyBack") private var legacyBack = 64
    @AppStorage("legacyRemastered") private var legacyRemastered = false
    @AppStorage("xpBack") private var xpBack = 54
    @AppStorage("xpRemastered") private var xpRemastered = false
    @AppStorage("vistaBackground") private var vistaBackground = "FELT"
    @AppStorage("vistaBack") private var vistaBack = 0
    @AppStorage("vistaDeck") private var vistaDeck = "VistaCards"
    @AppStorage("soundEnabled") private var sounds = false
    @State var drawCount: Int
    let setDraw: (Int) -> Void
    let preview: () -> Void
    private var theme: Binding<Int> { Binding(get: { vista ? 2 : (legacy ? 0 : 1) }, set: { value in legacy = value == 0; vista = value == 2 }) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Windows version", selection: theme) {
                        Text("Windows 98").tag(0); Text("Windows XP").tag(1); Text("Windows Vista").tag(2)
                    }.pickerStyle(.inline)
                    if vista {
                        Picker("Table", selection: $vistaBackground) {
                            Text("Classic felt").tag("FELT"); Text("Red hearts").tag("HEARTS"); Text("Green nature").tag("NATURE"); Text("Red felt").tag("REDFELT"); Text("Brown felt").tag("BROWNFELT")
                        }
                        Picker("Deck", selection: $vistaDeck) {
                            Text("Classic").tag("VistaCards"); Text("Hearts").tag("VistaHearts"); Text("Seasons").tag("VistaSeasons"); Text("Large print").tag("VistaLarge")
                        }
                        Picker("Card back", selection: $vistaBack) { Text("Red pattern").tag(0); Text("Red hearts").tag(2); Text("Blue pattern").tag(3) }
                    } else {
                        Toggle("Remastered artwork", isOn: legacy ? $legacyRemastered : $xpRemastered)
                        NavigationLink("Choose card back") { cardBacks }
                    }
                }
                Section("Game") {
                    Picker("Draw", selection: $drawCount) { Text("Draw 1").tag(1); Text("Draw 3").tag(3) }
                        .onChange(of: drawCount) { setDraw($0) }
                    Toggle("Vista sound effects", isOn: $sounds)
                    Button("Preview victory animation") { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { preview() } }
                }
                Section("Controls") { Text("Move to foundations moves all eligible cards to the four foundation piles.").font(.footnote) }
            }
            .navigationTitle("Game options")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    var cardBacks: some View {
        List(54...65, id: \.self) { back in
            Button {
                if legacy { legacyBack = back } else { xpBack = back }
            } label: {
                HStack(spacing: 16) {
                    cardImage(back).resizable().interpolation((legacy ? legacyRemastered : xpRemastered) ? .high : .none)
                        .frame(width: 42, height: 57).clipShape(RoundedRectangle(cornerRadius: 3))
                    Text(backName(back)).foregroundStyle(.primary)
                    Spacer()
                    if back == (legacy ? legacyBack : xpBack) { Image(systemName: "checkmark").foregroundStyle(.green) }
                }.frame(minHeight: 60).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.navigationTitle("Card backs")
    }
    func backName(_ number: Int) -> String {
        let names = legacy ? ["Pattern 1", "Pattern 2", "Robot", "Roses", "Flowers (black)", "Flowers (blue)", "Fish", "Aquarium", "Shell", "Castle", "Palm Beach", "Card Hand"] : ["Clouds", "Blue glass", "Fish", "Frog", "Rose", "Beach", "Blue tiles", "Purple lights", "Desert", "Astronaut", "Stripes", "Race cars"]
        return names[number - 54]
    }
    func cardImage(_ number: Int) -> Image {
        let folder = legacy ? (legacyRemastered ? "LegacyRemastered" : "LegacyCards") : (xpRemastered ? "XPRemastered" : "Cards")
        let path = Bundle.main.path(forResource: String(number), ofType: "png", inDirectory: folder)
        #if canImport(UIKit)
        if let path, let image = UIImage(contentsOfFile: path) { return Image(uiImage: image) }
        #elseif canImport(AppKit)
        if let path, let image = NSImage(contentsOfFile: path) { return Image(nsImage: image) }
        #endif
        return Image(systemName: "rectangle")
    }
}

private extension View {
    func floatingControlStyle() -> some View {
        self.font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
            .frame(width: 44, height: 44).background(.black.opacity(0.72), in: Circle())
    }
}

@available(iOS 27.1, *)
private struct VerticalBarObserver: View {
    @Environment(\.toolbarVerticalEdge) private var edge
    @Binding var isActive: Bool
    @Binding var isLeading: Bool
    var body: some View {
        Color.clear.allowsHitTesting(false)
            .onAppear { isActive = edge != nil; isLeading = edge == .leading }
            .onChange(of: edge) { isActive = $0 != nil; isLeading = $0 == .leading }
    }
}

#if canImport(UIKit)
@available(iOS 27.1, *)
private struct HingeObserver: UIViewRepresentable {
    @Binding var isOpen: Bool
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        let binding = $isOpen
        view.addInteraction(UIHingeInteraction { _, update in
            guard let hinge = update.hinge, hinge.status != .unknown else { return }
            let open = hinge.status != .closed
            DispatchQueue.main.async { if binding.wrappedValue != open { binding.wrappedValue = open } }
        })
        return view
    }
    func updateUIView(_ view: UIView, context: Context) { }
}
#endif
