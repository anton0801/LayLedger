//
//  FlocksView.swift
//  LayLedger
//
//  Flock list with create / archive, plus the Add Flock form.
//

import SwiftUI

struct FlocksView: View {
    @EnvironmentObject var store: DataStore
    @State private var showAdd = false
    @State private var editing: Flock? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Active flocks",
                              subtitle: "\(store.activeFlocks.count) flock(s) • \(store.totalActiveBirds) birds")

                if store.activeFlocks.isEmpty {
                    EmptyStateView(icon: "bird.fill", title: "No flocks yet",
                                   message: "Create your first flock to start tracking eggs and money.",
                                   actionTitle: "Create Flock") { showAdd = true }
                } else {
                    ForEach(store.activeFlocks) { flock in
                        flockCard(flock)
                    }
                }

                let archived = store.flocks.filter { $0.isArchived }
                if !archived.isEmpty {
                    SectionHeader(title: "Archived").padding(.top, 8)
                    ForEach(archived) { flock in
                        flockCard(flock)
                    }
                }

                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Flocks", displayMode: .inline)
        .navigationBarItems(trailing: Button { showAdd = true } label: {
            Image(systemName: "plus").font(.ll(17, .semibold)).foregroundColor(AppColor.accentActive)
        })
        .sheet(isPresented: $showAdd) {
            AddFlockView().environmentObject(store)
        }
        .sheet(item: $editing) { flock in
            AddFlockView(existing: flock).environmentObject(store)
        }
    }

    private func flockCard(_ flock: Flock) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(flock.name).font(.ll(18, .bold)).foregroundColor(AppColor.textPrimary)
                        if !flock.coopLabel.isEmpty {
                            Text(flock.coopLabel).font(.captionM).foregroundColor(AppColor.textSecondary)
                        }
                    }
                    Spacer()
                    Menu {
                        Button { editing = flock } label: { Label("Edit", systemImage: "pencil") }
                        Button { store.toggleArchive(flock) } label: {
                            Label(flock.isArchived ? "Unarchive" : "Archive",
                                  systemImage: flock.isArchived ? "tray.and.arrow.up" : "archivebox")
                        }
                        Button { store.deleteFlock(flock) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis").font(.ll(18, .bold))
                            .foregroundColor(AppColor.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                }

                HStack(spacing: 10) {
                    metric(value: "\(flock.birdsCount)", label: "Birds", icon: "bird")
                    metric(value: "\(Int(store.layRate(for: flock).rounded()))%", label: "Lay rate", icon: "percent")
                    metric(value: formatEggs(store.eggs(on: Date(), flockId: flock.id)), label: "Today", icon: "oval.portrait")
                }

                HStack {
                    Text("Updated \(relativeUpdated(flock.updatedAt))")
                        .font(.ll(11, .medium)).foregroundColor(AppColor.textDisabled)
                    Spacer()
                    NavigationLink(destination: BreedsView(flock: flock)) {
                        Text("Breeds →").font(.ll(13, .semibold)).foregroundColor(AppColor.accentActive)
                    }
                }
            }
        }
        .opacity(flock.isArchived ? 0.6 : 1)
    }

    private func metric(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.ll(12, .semibold)).foregroundColor(AppColor.accentActive)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.ll(15, .bold)).foregroundColor(AppColor.textPrimary)
                Text(label).font(.ll(10, .medium)).foregroundColor(AppColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(AppColor.bgSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Add / Edit Flock

struct AddFlockView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.presentationMode) private var presentationMode

    var existing: Flock? = nil

    @State private var name = ""
    @State private var coop = ""
    @State private var birds = 0
    @State private var startDate = Date()
    @State private var notes = ""
    @State private var showError = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    LabeledTextField(label: "Flock name", placeholder: "e.g. Backyard Layers",
                                     text: $name, icon: "bird.fill")
                    LabeledTextField(label: "Coop / label", placeholder: "e.g. Coop A",
                                     text: $coop, icon: "house.fill")
                    Card {
                        StepperField(label: "Birds count", value: $birds, range: 0...100000)
                    }
                    Card {
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                            .font(.bodyM)
                            .accentColor(AppColor.accentActive)
                            .foregroundColor(AppColor.textPrimary)
                    }
                    LabeledMultilineField(label: "Notes", text: $notes)

                    LLButton(title: "Save Flock", icon: "checkmark") { save() }
                        .padding(.top, 4)

                    if showError {
                        Text("Please enter a flock name.")
                            .font(.captionM).foregroundColor(AppColor.problem)
                    }
                }
                .padding(18)
            }
            .background(AppColor.bgGradient.ignoresSafeArea())
            .navigationBarTitle(existing == nil ? "Add Flock" : "Edit Flock", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { dismiss() })
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        guard let f = existing else { return }
        name = f.name; coop = f.coopLabel; birds = f.birdsCount
        startDate = f.startDate; notes = f.notes
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            withAnimation { showError = true }; return
        }
        if var f = existing {
            f.name = name; f.coopLabel = coop; f.birdsCount = birds
            f.startDate = startDate; f.notes = notes
            store.updateFlock(f)
        } else {
            var f = Flock(name: name)
            f.coopLabel = coop; f.birdsCount = birds; f.startDate = startDate; f.notes = notes
            store.addFlock(f)
        }
        dismiss()
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
