import SwiftUI

/// 初回投稿時などにニックネームを設定するシート。
struct NicknameSheet: View {
    var currentNickname: String = ""
    var onSaved: (UserProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ニックネーム（20文字まで）", text: $nickname)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("みんなの図書館で表示される名前")
                } footer: {
                    Text("本名は不要です。あとから変更できます。不適切な投稿は通報・削除の対象になります。")
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("ニックネーム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "保存") { save() }
                        .disabled(isSaving || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { nickname = currentNickname }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let profile = try await SocialService.shared.saveNickname(nickname)
                await MainActor.run {
                    isSaving = false
                    onSaved(profile)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}
