import SwiftUI

// MARK: - FlowLayout
//
// A simple left-to-right, top-to-bottom flowing layout — think "wrapping HStack"
// for tag/chip rows. Rows break to a new line when the next subview would
// overflow the proposed width.
//
// Originally lived inside AddPlaceFlow.swift; extracted into its own file
// when AddPlaceFlow was deleted so AddPlaceTestFlow (and anything else that
// wants chip wrapping) still compiles.
//
// Usage:
//   FlowLayout(spacing: 8) {
//       ForEach(tags, id: \.self) { chip($0) }
//   }

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { acc, row in
            acc + row.height + (acc == 0 ? 0 : spacing)
        }
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    // MARK: - Row Packing

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needsSpacing = !rows[rows.count - 1].indices.isEmpty
            let projectedWidth = rows[rows.count - 1].width
                + (needsSpacing ? spacing : 0)
                + size.width

            if projectedWidth > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }

            var current = rows[rows.count - 1]
            if !current.indices.isEmpty { current.width += spacing }
            current.indices.append(index)
            current.width += size.width
            current.height = max(current.height, size.height)
            rows[rows.count - 1] = current
        }
        return rows
    }
}
