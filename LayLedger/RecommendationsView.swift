//
//  RecommendationsView.swift
//  LayLedger
//
//  Data-driven advice. Add to Tasks / Save / Dismiss are all wired to the store.
//

import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var store: DataStore
    @State private var addedKeys: Set<String> = []
    @State private var showToast = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Recommendations",
                              subtitle: "Based on your recent eggs and money")

                let recs = store.generateRecommendations()
                if recs.isEmpty {
                    EmptyStateView(icon: "checkmark.seal.fill", title: "All clear",
                                   message: "No issues detected. Keep logging to get fresh tips.") { }
                } else {
                    ForEach(recs) { rec in
                        card(rec)
                    }
                }
                Color.clear.frame(height: 1)
            }
            .padding(.horizontal, 18).padding(.top, 8).bottomBarInset()
        }
        .background(AppColor.bgGradient.ignoresSafeArea())
        .navigationBarTitle("Recommendations", displayMode: .inline)
        .toast(isShowing: $showToast, message: "Added to tasks")
    }

    private func card(_ rec: Recommendation) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(rec.severity.color.opacity(0.16)).frame(width: 40, height: 40)
                        Image(systemName: rec.severity.icon).foregroundColor(rec.severity.color).font(.ll(17, .bold))
                    }
                    Text(rec.title).font(.ll(17, .bold)).foregroundColor(AppColor.textPrimary)
                    Spacer()
                    if store.savedRecKeys.contains(rec.key) {
                        Image(systemName: "bookmark.fill").foregroundColor(AppColor.accent)
                    }
                }
                Text(rec.body).font(.bodyM).foregroundColor(AppColor.textSecondary)

                if !rec.suggestedTask.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.down.right").font(.ll(11, .bold))
                        Text(rec.suggestedTask).font(.ll(13, .semibold))
                    }
                    .foregroundColor(AppColor.accentActive)
                }

                HStack(spacing: 10) {
                    LLButton(title: addedKeys.contains(rec.key) ? "Added" : "Add to Tasks",
                             icon: addedKeys.contains(rec.key) ? "checkmark" : "checklist",
                             kind: addedKeys.contains(rec.key) ? .success : .secondary,
                             fullWidth: true) { addTask(rec) }
                    Button { toggleSave(rec) } label: {
                        Image(systemName: store.savedRecKeys.contains(rec.key) ? "bookmark.fill" : "bookmark")
                            .font(.ll(16, .bold)).foregroundColor(AppColor.accentActive)
                            .frame(width: 46, height: 46).background(AppColor.depth).cornerRadius(14)
                    }
                    .buttonStyle(PressableButtonStyle())
                    Button { dismissRec(rec) } label: {
                        Image(systemName: "xmark").font(.ll(16, .bold)).foregroundColor(AppColor.problem)
                            .frame(width: 46, height: 46).background(AppColor.problem.opacity(0.12)).cornerRadius(14)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private func addTask(_ rec: Recommendation) {
        guard !addedKeys.contains(rec.key) else { return }
        let title = rec.suggestedTask.isEmpty ? rec.title : rec.suggestedTask
        store.addTask(TaskItem(title: title,
                               dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            addedKeys.insert(rec.key)
            showToast = true
        }
    }

    private func toggleSave(_ rec: Recommendation) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if store.savedRecKeys.contains(rec.key) { store.savedRecKeys.remove(rec.key) }
            else { store.savedRecKeys.insert(rec.key) }
        }
    }

    private func dismissRec(_ rec: Recommendation) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            store.dismissedRecKeys.insert(rec.key)
        }
    }
}
