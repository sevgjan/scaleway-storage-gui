//
//  AccountRow.swift
//  ScalewayGUI
//
//  Created by Sevgjan Haxhija on 2/12/26.
//
import SwiftUI

struct AccountRow: View {
    let account: AccountProfile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                Text(account.signingRegion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
