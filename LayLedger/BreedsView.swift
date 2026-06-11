//
//  BreedsView.swift
//  LayLedger
//
//  Breed list (optionally scoped to a flock) with filter, plus the Add Breed form.
//

import SwiftUI

struct BreedsView: View {
    @EnvironmentObject var store: DataStore
    var flock: Flock? = nil

    @State private var showAdd = false
    @State private var editing: Breed? = nil
    @State private var statusFilter: LayStatus? = nil

    private var breeds: [Breed] {
        var list = flock == nil ? store.breeds : store.breeds(for: flock!)
        if let status = statusFilter {
            list = list.filter { store.breedStatus($0) == status }
        }
        return list
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: flock?.name ?? "All breeds",
                              subtitle: "\(breeds.count) breed(s)")

                if let status = statusFilter {
                    HStack {
                        TagChip(text: "Filter: \(status.title)", color: status.color, filled: true)
                        Button { withAnimation { statusFilter = nil } } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(AppColor.textDisabled)
                        }
                    }
                }

                if breeds.isEmpty {
                    EmptyStateView(icon: "checklist", title: "No breeds",
                                   message: "Add breeds so Lay Ledger can track per-breed lay rate.",
                                   actionTitle: "Add Breed") { showAdd = true }
                } else {
                    ForEach(breeds) { breed in
                        breedCard(breed)
                    }
                }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Breeds", displayMode: .inline)
        .navigationBarItems(trailing: HStack(spacing: 16) {
            Menu {
                Button("All statuses") { statusFilter = nil }
                ForEach(LayStatus.allCases, id: \.self) { s in
                    Button(s.title) { statusFilter = s }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.ll(17, .semibold)).foregroundColor(AppColor.accentActive)
            }
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.ll(17, .semibold)).foregroundColor(AppColor.accentActive)
            }
        })
        .sheet(isPresented: $showAdd) {
            AddBreedView(presetFlock: flock).environmentObject(store)
        }
        .sheet(item: $editing) { breed in
            AddBreedView(existing: breed).environmentObject(store)
        }
    }

    private func breedCard(_ breed: Breed) -> some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color(hex: breed.colorHex).opacity(0.18))
                        .frame(width: 60, height: 60)
                    if let image = Image(data: breed.photo) {
                        image.resizable().scaledToFill().frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        EggShape().fill(Color(hex: breed.colorHex)).frame(width: 26, height: 34)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(breed.name).font(.ll(17, .bold)).foregroundColor(AppColor.textPrimary)
                    if flock == nil, let f = store.flock(breed.flockId) {
                        Text(f.name).font(.ll(11, .medium)).foregroundColor(AppColor.textSecondary)
                    }
                    HStack(spacing: 12) {
                        Text("\(breed.birdsCount) birds").font(.captionM).foregroundColor(AppColor.textSecondary)
                        Text(String(format: "%.1f eggs/wk", store.breedAveragePerDay(breed) * 7))
                            .font(.captionM).foregroundColor(AppColor.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    StatusBadge(status: store.breedStatus(breed))
                    Menu {
                        Button { editing = breed } label: { Label("Edit", systemImage: "pencil") }
                        Button { store.deleteBreed(breed) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis").font(.ll(16, .bold))
                            .foregroundColor(AppColor.textSecondary).frame(width: 28, height: 22)
                    }
                }
            }
        }
    }
}

// MARK: - Add / Edit Breed

struct AddBreedView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.presentationMode) private var presentationMode

    var presetFlock: Flock? = nil
    var existing: Breed? = nil

    @State private var flockId: UUID? = nil
    @State private var name = ""
    @State private var birds = 0
    @State private var expectedPerDay = "0.8"
    @State private var colorHex = "F59E0B"
    @State private var photo: Data? = nil
    @State private var showPicker = false
    @State private var showError = false

    private let swatches = ["F59E0B", "D97706", "FBBF24", "0D9488", "14B8A6", "22C55E", "EF4444", "78622C"]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if existing == nil, presetFlock == nil {
                        flockPicker
                    }
                    coverPhoto
                    LabeledTextField(label: "Breed name", placeholder: "e.g. Rhode Island Red",
                                     text: $name, icon: "checklist")
                    Card { StepperField(label: "Birds count", value: $birds, range: 0...100000) }
                    LabeledNumberField(label: "Expected eggs/day (per bird)", placeholder: "0.8",
                                       value: $expectedPerDay, icon: "oval.portrait", unit: "egg/day")
                    colorTag
                    LLButton(title: "Save Breed", icon: "checkmark") { save() }
                        .padding(.top, 4)
                    if showError {
                        Text("Enter a breed name and choose a flock.")
                            .font(.captionM).foregroundColor(AppColor.problem)
                    }
                }
                .padding(18)
            }
            .background(AppColor.bgGradient.ignoresSafeArea())
            .navigationBarTitle(existing == nil ? "Add Breed" : "Edit Breed", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { dismiss() })
            .onAppear(perform: prefill)
            .sheet(isPresented: $showPicker) { PhotoPicker(imageData: $photo) }
        }
    }

    private var flockPicker: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Flock").font(.captionM).foregroundColor(AppColor.textSecondary)
                Menu {
                    ForEach(store.activeFlocks) { f in
                        Button(f.name) { flockId = f.id }
                    }
                } label: {
                    HStack {
                        Text(store.flock(flockId)?.name ?? "Select flock")
                            .font(.bodyM).foregroundColor(AppColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").foregroundColor(AppColor.textDisabled)
                    }
                }
            }
        }
    }

    private var coverPhoto: some View {
        Button { showPicker = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(AppColor.bgSecondary)
                    .frame(height: 150)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColor.border, lineWidth: 1))
                if let image = Image(data: photo) {
                    image.resizable().scaledToFill().frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill").font(.ll(24, .bold)).foregroundColor(AppColor.accent)
                        Text("Add cover photo").font(.captionM).foregroundColor(AppColor.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var colorTag: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Color tag").font(.captionM).foregroundColor(AppColor.textSecondary)
                HStack(spacing: 10) {
                    ForEach(swatches, id: \.self) { hex in
                        Circle().fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(AppColor.textPrimary,
                                                     lineWidth: colorHex == hex ? 3 : 0))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { colorHex = hex }
                            }
                    }
                }
            }
        }
    }

    private func prefill() {
        if let b = existing {
            flockId = b.flockId; name = b.name; birds = b.birdsCount
            expectedPerDay = String(b.expectedEggsPerDay); colorHex = b.colorHex; photo = b.photo
        } else if let f = presetFlock {
            flockId = f.id
        } else {
            flockId = store.activeFlocks.first?.id
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let fid = flockId else {
            withAnimation { showError = true }; return
        }
        let expected = Double(expectedPerDay.replacingOccurrences(of: ",", with: ".")) ?? 0
        if var b = existing {
            b.flockId = fid; b.name = trimmed; b.birdsCount = birds
            b.expectedEggsPerDay = expected; b.colorHex = colorHex; b.photo = photo
            store.updateBreed(b)
        } else {
            var b = Breed(flockId: fid, name: trimmed)
            b.birdsCount = birds; b.expectedEggsPerDay = expected; b.colorHex = colorHex; b.photo = photo
            store.addBreed(b)
        }
        dismiss()
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
