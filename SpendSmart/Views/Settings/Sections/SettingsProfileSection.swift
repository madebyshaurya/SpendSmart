import SwiftUI

struct SettingsProfileSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var userEmoji: String
    @Binding var showEmojiPicker: Bool
    let onHaptic: () -> Void

    var body: some View {
        Section {
            HStack(spacing: 16) {
                Button {
                    onHaptic()
                    showEmojiPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.brandAccentLight)
                            .frame(width: 60, height: 60)

                        Text(userEmoji)
                            .font(.system(size: 32))

                        Circle()
                            .fill(Color.brandVibrantBlue)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 20, y: 20)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        if viewModel.isEditingName {
                            TextField("Display name", text: $viewModel.pendingDisplayName)
                                .font(.headline)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.gray.opacity(0.12))
                                .cornerRadius(12)
                        } else {
                            Text(viewModel.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        if viewModel.isEditingName {
                            Button {
                                viewModel.cancelEditingName()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            Button {
                                viewModel.saveDisplayName()
                            } label: {
                                if viewModel.isSavingDisplayName {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.green)
                            .disabled(viewModel.isSavingDisplayName)
                        } else {
                            Button {
                                viewModel.beginEditingName()
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Text(viewModel.userEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $userEmoji)
                    .presentationDetents([.medium])
            }
        } header: {
            Text("Account")
        }
    }
}
