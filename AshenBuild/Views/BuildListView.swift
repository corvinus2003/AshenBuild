import SwiftUI
import SwiftData

/// App appearance, chosen in Settings. Dark by default.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: Self { self }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Home screen: the app mark, a large Start button and the saved builds.
struct BuildListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DataStore.self) private var dataStore
    @Query(sort: \SavedBuild.updatedAt, order: .reverse) private var builds: [SavedBuild]

    @State private var path: [SavedBuild] = []
    @State private var showingNewBuildSheet = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    hero
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if !builds.isEmpty {
                    Section("Your Builds") {
                        ForEach(builds) { build in
                            NavigationLink(value: build) {
                                BuildRow(build: build)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    delete(build)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button("Duplicate", systemImage: "plus.square.on.square") {
                                    duplicate(build)
                                }
                                .tint(.indigo)
                            }
                            .contextMenu {
                                Button("Duplicate", systemImage: "plus.square.on.square") {
                                    duplicate(build)
                                }
                                Divider()
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    delete(build)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ashen Build")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SavedBuild.self) { build in
                BuildEditorView(build: build)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Settings", systemImage: "gearshape") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingNewBuildSheet) {
                NewBuildSheet { newBuild in
                    modelContext.insert(newBuild)
                    path = [newBuild]
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Image("AppMark")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .shadow(color: .orange.opacity(0.25), radius: 18, y: 6)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Is your build optimized?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Pick a class, set your stats and gear. Ashen Build checks every point and suggests a better respec.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)

            Button {
                showingNewBuildSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                    Text("Start")
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .padding(.top, 6)
            .accessibilityHint("Creates a new build")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func delete(_ build: SavedBuild) {
        withAnimation {
            modelContext.delete(build)
        }
    }

    private func duplicate(_ build: SavedBuild) {
        withAnimation {
            modelContext.insert(build.duplicate())
        }
    }
}

/// Rounded-square class glyph, like the icons in Settings.
struct ClassBadge: View {
    let symbolName: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.accentColor.gradient, in: .rect(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct BuildRow: View {
    @Environment(DataStore.self) private var dataStore
    let build: SavedBuild

    var body: some View {
        let cls = dataStore.startingClass(build.classID)
        HStack(spacing: 12) {
            ClassBadge(symbolName: cls?.symbolName ?? "circle.dashed")
            VStack(alignment: .leading, spacing: 2) {
                Text(build.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(cls?.name ?? "Unknown Class") · SL \(Formulas.soulLevel(for: build.statBlock))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(build.updatedAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

private struct NewBuildSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var dataStore
    let onCreate: (SavedBuild) -> Void

    @State private var name: String = ""
    @State private var selectedClassID: String = "knight"

    private var selectedClass: StartingClass? { dataStore.startingClass(selectedClassID) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(selectedClass.map { "\($0.name) Build" } ?? "Build Name", text: $name)
                        .submitLabel(.done)
                } header: {
                    Text("Name")
                }

                Section {
                    ForEach(dataStore.startingClasses) { cls in
                        Button {
                            selectedClassID = cls.id
                        } label: {
                            HStack(spacing: 12) {
                                ClassBadge(symbolName: cls.symbolName, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cls.name)
                                    Text("Soul Level \(Formulas.soulLevel(for: cls.statBlock))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if cls.id == selectedClassID {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .foregroundStyle(.primary)
                            .contentShape(Rectangle())
                        }
                        .tint(.primary)
                        .accessibilityAddTraits(cls.id == selectedClassID ? .isSelected : [])
                    }
                } header: {
                    Text("Starting Class")
                } footer: {
                    if let flavor = selectedClass?.flavor {
                        Text(flavor)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedClassID)
            .navigationTitle("New Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(selectedClass == nil)
                }
            }
            .onAppear {
                if selectedClass == nil, let first = dataStore.startingClasses.first {
                    selectedClassID = first.id
                }
            }
        }
    }

    private func create() {
        guard let cls = selectedClass else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = SavedBuild(
            name: trimmed.isEmpty ? "\(cls.name) Build" : trimmed,
            classID: cls.id,
            statBlock: cls.statBlock
        )
        if cls.startingWeaponIDs.indices.contains(0) {
            build.mainHandWeaponID = cls.startingWeaponIDs[0]
        }
        if cls.startingWeaponIDs.indices.contains(1) {
            build.offHandWeaponID = cls.startingWeaponIDs[1]
        }
        for id in cls.startingArmorIDs {
            if let armor = dataStore.armorPiece(id) {
                switch armor.slot {
                case .head: build.headArmorID = id
                case .chest: build.chestArmorID = id
                case .hands: build.handsArmorID = id
                case .legs: build.legsArmorID = id
                }
            }
        }
        onCreate(build)
        dismiss()
    }
}

/// Appearance, app information, the unofficial-app disclaimer and the privacy statement.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance: AppAppearance = .dark

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image("AppMark")
                            .resizable()
                            .frame(width: 84, height: 84)
                            .clipShape(.rect(cornerRadius: 19, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                            .accessibilityHidden(true)
                        Text("Ashen Build")
                            .font(.title2.weight(.semibold))
                        Text(versionString)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("About") {
                    Text("Plan character builds: choose a starting class, allocate stats, equip weapons, armor and rings, and see the totals at a glance.")
                }

                Section {
                    Text("Ashen Build is an unofficial, fan-made companion tool. It is not affiliated with, endorsed, sponsored or approved by FromSoftware or Bandai Namco Entertainment. Game titles, item names and other game terms belong to their respective owners and are used only to identify in-game content.")
                } header: {
                    Text("Unofficial Fan App")
                } footer: {
                    Text("Numbers are calculated from community-documented formulas and may differ slightly from what you see in the game.")
                }

                Section("Privacy") {
                    Text("Ashen Build does not collect, share or transmit any data. It has no accounts, ads, analytics or tracking. Your builds are stored only on this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
