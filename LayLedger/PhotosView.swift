//
//  PhotosView.swift
//  LayLedger
//
//  Photo log by category with a compare mode.
//

import SwiftUI

struct PhotosView: View {
    @EnvironmentObject var store: DataStore
    @State private var categoryFilter: PhotoCategory? = nil
    @State private var compareMode = false
    @State private var selected: [PhotoItem] = []
    @State private var showAdd = false
    @State private var showCompare = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                categoryChips
                if compareMode {
                    Text("Select two photos to compare (\(selected.count)/2)")
                        .font(.captionM).foregroundColor(AppColor.accentActive)
                }
                let items = store.photos(categoryFilter)
                if items.isEmpty {
                    EmptyStateView(icon: "photo.on.rectangle.angled", title: "No photos",
                                   message: "Capture eggs, birds, the coop or a sale batch.",
                                   actionTitle: "Add Photo") { showAdd = true }
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { photo in
                            thumbnail(photo)
                        }
                    }
                }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Photos", displayMode: .inline)
        .navigationBarItems(trailing: HStack(spacing: 16) {
            Button { toggleCompare() } label: {
                Image(systemName: compareMode ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle")
                    .font(.ll(16, .semibold))
                    .foregroundColor(compareMode ? AppColor.problem : AppColor.accentActive)
            }
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.ll(17, .semibold)).foregroundColor(AppColor.accentActive)
            }
        })
        .sheet(isPresented: $showAdd) { AddPhotoView().environmentObject(store) }
        .sheet(isPresented: $showCompare) {
            if selected.count == 2 { PhotoCompareView(a: selected[0], b: selected[1]) }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", active: categoryFilter == nil) { categoryFilter = nil }
                ForEach(PhotoCategory.allCases) { c in
                    chip(title: c.title, active: categoryFilter == c) { categoryFilter = c }
                }
            }
        }
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            Text(title)
                .font(.ll(13, .semibold))
                .foregroundColor(active ? AppColor.onAccent : AppColor.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(active ? AppColor.accent : AppColor.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColor.border, lineWidth: active ? 0 : 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func thumbnail(_ photo: PhotoItem) -> some View {
        let isSelected = selected.contains { $0.id == photo.id }
        return ZStack(alignment: .topTrailing) {
            (Image(data: photo.image) ?? Image(systemName: "photo"))
                .resizable().scaledToFill()
                .frame(height: 150).frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? AppColor.accent : AppColor.border,
                                lineWidth: isSelected ? 3 : 1)
                )
                .overlay(captionOverlay(photo), alignment: .bottomLeading)

            if compareMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.ll(20, .bold)).foregroundColor(isSelected ? AppColor.accent : .white)
                    .padding(8)
            } else {
                Menu {
                    Button { store.deletePhoto(photo) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill").font(.ll(18, .bold))
                        .foregroundColor(.white).padding(8)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { tap(photo) }
    }

    private func captionOverlay(_ photo: PhotoItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer()
            HStack {
                TagChip(text: photo.category.title, color: AppColor.accent, filled: true)
                Spacer()
            }
        }
        .padding(8)
    }

    private func tap(_ photo: PhotoItem) {
        guard compareMode else { return }
        if let idx = selected.firstIndex(where: { $0.id == photo.id }) {
            selected.remove(at: idx)
        } else if selected.count < 2 {
            selected.append(photo)
            if selected.count == 2 { showCompare = true }
        }
    }

    private func toggleCompare() {
        withAnimation { compareMode.toggle(); selected.removeAll() }
    }
}

struct PhotoCompareView: View {
    let a: PhotoItem
    let b: PhotoItem
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    comparePane(a, label: "A")
                    comparePane(b, label: "B")
                }
                .padding(18)
            }
            .background(AppColor.bgGradient.ignoresSafeArea())
            .navigationBarTitle("Compare", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() })
        }
    }

    private func comparePane(_ photo: PhotoItem, label: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TagChip(text: "Photo \(label)", color: AppColor.teal, filled: true)
                    Spacer()
                    Text(mediumDate(photo.date)).font(.captionM).foregroundColor(AppColor.textSecondary)
                }
                (Image(data: photo.image) ?? Image(systemName: "photo"))
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(photo.category.title).font(.ll(15, .semibold)).foregroundColor(AppColor.textPrimary)
                if !photo.caption.isEmpty {
                    Text(photo.caption).font(.bodyM).foregroundColor(AppColor.textSecondary)
                }
            }
        }
    }
}

struct AddPhotoView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var category: PhotoCategory = .eggs
    @State private var photo: Data? = nil
    @State private var caption = ""
    @State private var showPicker = false
    @State private var showError = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Button { showPicker = true } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18).fill(AppColor.bgSecondary).frame(height: 220)
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColor.border, lineWidth: 1))
                            if let image = Image(data: photo) {
                                image.resizable().scaledToFill().frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill").font(.ll(28, .bold)).foregroundColor(AppColor.accent)
                                    Text("Choose photo").font(.bodyM).foregroundColor(AppColor.textSecondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(PressableButtonStyle())

                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Category").font(.captionM).foregroundColor(AppColor.textSecondary)
                            LLSegmented(options: PhotoCategory.allCases, selection: $category) { $0.title }
                        }
                    }
                    LabeledTextField(label: "Caption", placeholder: "Optional note", text: $caption, icon: "text.alignleft")
                    LLButton(title: "Save Photo", icon: "checkmark") { save() }
                    if showError {
                        Text("Choose a photo first.").font(.captionM).foregroundColor(AppColor.problem)
                    }
                }
                .padding(18)
            }
            .background(AppColor.bgGradient.ignoresSafeArea())
            .navigationBarTitle("Add Photo", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() })
            .sheet(isPresented: $showPicker) { PhotoPicker(imageData: $photo) }
        }
    }

    private func save() {
        guard let data = photo else { withAnimation { showError = true }; return }
        var item = PhotoItem(image: data)
        item.category = category
        item.caption = caption
        store.addPhoto(item)
        presentationMode.wrappedValue.dismiss()
    }
}
