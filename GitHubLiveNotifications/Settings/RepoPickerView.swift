import GHNCore
import SwiftUI

/// Searchable repo list with ownership filters and selection steppers (UI-SPEC §3.1).
struct RepoPickerView: View {
    @ObservedObject var selection: RepoSelectionController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField
            filterRow
            selectionSummary
            repoList
        }
        .task {
            await selection.loadIfNeeded()
        }
    }

    private var searchField: some View {
        TextField("Search repositories", text: $selection.searchQuery)
            .textFieldStyle(.roundedBorder)
            .font(GHNFont.rowTitle)
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            filterToggle("Owned", kind: .owned)
            filterToggle("Collaborator", kind: .collaborator)
            filterToggle("Org", kind: .org)
        }
    }

    private func filterToggle(_ title: String, kind: RepoOwnershipKind) -> some View {
        let isOn = selection.activeFilters.contains(kind)
        return Button(title) {
            selection.toggleFilter(kind)
        }
        .buttonStyle(.bordered)
        .tint(isOn ? GHNColor.accentSignal : GHNColor.textTertiary)
        .font(GHNFont.meta)
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(selection.selectedCount) of \(RepoPickerLimits.maxSelected) selected")
                .font(GHNFont.mono)
                .foregroundStyle(GHNColor.textSecondary)

            if selection.shouldWarnSelection(currentCount: selection.selectedCount) {
                Text("Approaching the \(RepoPickerLimits.warnThreshold)-repo warning threshold — polling cost rises with each selection.")
                    .font(GHNFont.meta)
                    .foregroundStyle(GHNColor.stateWarn)
            }
        }
    }

    private var repoList: some View {
        Group {
            switch selection.loadState {
            case .idle, .loading:
                ProgressView("Loading repositories…")
                    .font(GHNFont.meta)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .failed(let message):
                Text(message)
                    .font(GHNFont.meta)
                    .foregroundStyle(GHNColor.stateDanger)
            case .loaded:
                if selection.filteredRepos.isEmpty {
                    Text("No repositories match your filters.")
                        .font(GHNFont.meta)
                        .foregroundStyle(GHNColor.textSecondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(selection.filteredRepos, id: \.id) { repo in
                                repoRow(repo)
                                if repo.id != selection.filteredRepos.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
    }

    private func repoRow(_ repo: GitHubRepository) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.fullName)
                    .font(GHNFont.rowTitle)
                    .lineLimit(1)
                Text(repoSubtitle(repo))
                    .font(GHNFont.meta)
                    .foregroundStyle(GHNColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Stepper(
                value: stepperBinding(for: repo),
                in: 0...1,
                step: 1
            ) {
                Text(selection.isSelected(repo) ? "On" : "Off")
                    .font(GHNFont.mono)
                    .foregroundStyle(
                        selection.isSelected(repo) ? GHNColor.accentSignal : GHNColor.textTertiary
                    )
                    .frame(width: 28, alignment: .trailing)
            }
            .labelsHidden()
            .disabled(!selection.isSelected(repo) && !selection.canSelectMore())
        }
        .padding(.vertical, 6)
    }

    private func stepperBinding(for repo: GitHubRepository) -> Binding<Int> {
        Binding(
            get: { selection.isSelected(repo) ? 1 : 0 },
            set: { newValue in
                selection.setSelected(repo, enabled: newValue == 1)
            }
        )
    }

    private func repoSubtitle(_ repo: GitHubRepository) -> String {
        var tags: [String] = []
        if repo.fork { tags.append("fork") }
        if repo.archived { tags.append("archived") }
        if repo.isPrivate { tags.append("private") }
        if tags.isEmpty { return repo.ownerLogin }
        return "\(repo.ownerLogin) · \(tags.joined(separator: " · "))"
    }
}

private extension RepoSelectionController {
    func shouldWarnSelection(currentCount: Int) -> Bool {
        RepoPicker.shouldWarnSelection(currentCount: currentCount)
    }
}
