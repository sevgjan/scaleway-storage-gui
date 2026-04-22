//
//  ObjectRow.swift
//  ScalewayGUI
//
//  Created by Sevgjan Haxhija on 2/12/26.
//
import SwiftUI

struct ObjectRow: View {
    let item: ObjectItem

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.isFolder ? Color.yellow.opacity(0.16) : Color.secondary.opacity(0.13))
                    .frame(width: 26, height: 24)
                Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                    .font(.caption)
                    .foregroundStyle(item.isFolder ? .yellow : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
