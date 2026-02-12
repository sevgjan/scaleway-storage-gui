//
//  BucketRow.swift
//  ScalewayGUI
//
//  Created by Sevgjan Haxhija on 2/12/26.
//
import SwiftUI

struct BucketRow: View {
    let name: String
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.secondary)
            Text(name)
                .lineLimit(1)
            Spacer(minLength: 8)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}
