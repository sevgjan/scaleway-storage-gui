//
//  BreadcrumbBar.swift
//  ScalewayGUI
//
//  Created by Sevgjan Haxhija on 2/12/26.
//
import SwiftUI

struct BreadcrumbBar: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Array(store.breadcrumbItems.enumerated()), id: \.element.id) { index, crumb in
                    let isCurrent = index == store.breadcrumbItems.count - 1
                    Button(crumb.title) {
                        Task { @MainActor in
                            await store.navigateToPrefix(crumb.prefix)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isCurrent ? Color.accentColor.opacity(0.18) : Color.quaternary.opacity(0.55))
                    )
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    .fontWeight(isCurrent ? .semibold : .regular)

                    if index < store.breadcrumbItems.count - 1 {
                        Text("/")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
