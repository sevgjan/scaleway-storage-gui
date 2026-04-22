//
//  AccountRow.swift
//  ScalewayGUI
//
//  Created by Sevgjan Haxhija on 2/12/26.
//
import SwiftUI

struct AccountRow: View {
    let account: AccountProfile
    let isActive: Bool
    var onEdit: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.secondary)
            Text(account.displayName)
                .lineLimit(1)
            Spacer(minLength: 8)
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Edit Account")
        }
        .padding(.vertical, 2)
    }
}
