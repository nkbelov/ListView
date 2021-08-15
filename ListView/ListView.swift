//
//  ListView.swift
//  ListView
//
//  Created by WTEDST on 14.08.21.
//

import Foundation
import UIKit

/// A structure to store the layout information of each row in a `ListView`.
/// Since the rows are always stretched to fill the full width of the `ListView`, we do not have
/// to record their x-position or their width. All that matters to us is knowing where they are located
/// on the vertical axis — and thus we only need their `y` coordinate and their `height`.
/// We mainly need this to 1. use less memory and 2. be more cache-friendly on searches.
struct Vertical {
    
    var y: CGFloat
    var height: CGFloat
    
    /// A convenience property to calculate the position of the bottom edge of the row
    var maxY: CGFloat { y + height }
    
    init(y: CGFloat, height: CGFloat) {
        precondition(height >= 0)
        self.y = y
        self.height = height
    }
    
    /// This function will be used to test if a view with a given `Vertical` is not inside the `bounds`
    /// of the `ListView` anymore and thus needs to be reused.
    func intersects(_ other: Vertical) -> Bool {
        // Two verticals intersect if none of the two coordinates (y and maxY)
        // of one lie completely to one side of the other vertical
        //            v~~~above      v~~~below
        return !(maxY < other.y || y > other.maxY)
        
    }
    
    func intersects(_ rect: CGRect) -> Bool {
        return intersects(rect.vertical)
    }
}

extension CGRect {
    
    /// A convenience property to extract a `Vertical` from views' frames
    var vertical: Vertical {
        return Vertical(y: minY, height: height)
    }
    
}

/// With protocols at hand, we don't need a separate class equivalent to `UITableViewCell`. In fact, the only
/// requirement is the empty initialiser — because `ListView` is responsible of creating new views
/// when there aren't any ready to be reused. Otherwise, any view is free to become a row view — no need to subclass!
protocol RowView: UIView {
    init()
}

final class ListView: UIScrollView {
    
    static let defaultRowHeight: CGFloat = 50
    
    /// The index of a row, corresponds to `IndexPath`.
    struct Index: Hashable {
        
        var section: Int
        var row: Int
        
        init(section: Int, row: Int) {
            self.section = section
            self.row = row
        }
    }
    
    /// The dimensions of the list. The position in the array corresponds to a section,
    /// and the integer entry corresponds to the number of rows in that section.
    private(set) var dimensions: [Int] = []
    
    /// The set of currently displayed rows. Rougly corresponds to `visibleCells` and `indexPathsForVisibleRows`,
    /// except that now it is one dictionary.
    private(set) var displayedRows = [Index: RowView]()
    
    /// Stores the layout information of each individual row.
    private var verticals = [Index: Vertical]()
    
    /// The reuse pool. The key is an object identifier corresponding to the dynamic type of a row. When rows are reused,
    /// they need to be put into the appropriate array, so that when we retreive them later, we get a view of the right type.
    /// The key is thus equivalent to a `reuseIdentifier` within `UITableView`.
    private var pool = [ObjectIdentifier: [RowView]]()
    
    /// This is the equivalent of `cellForRow(at:)` method in `UITableViewDataSource`.
    private var rowViewSource: Optional<(Index, ListView) -> RowView> = nil
    
    /// The main API to `ListView`: it registers the initial sizes of the sections and supplies the closure
    /// which will be used to populate the rows as they appear on screen.
    /// This is equivlent to setting a `dataSource` of `UITableView`.
    func reload(dimensions: [Int], rowViewSource: @escaping (Index, ListView) -> RowView) {
        self.rowViewSource = rowViewSource
        
        // First, hide all views that we are displaying already
        for index in displayedRows.keys {
           reuse(at: index)
        }
        
        assert(displayedRows.isEmpty)
        
        let rowCount = dimensions.reduce(0, +)
        
        verticals.removeAll(keepingCapacity: true)
        verticals.reserveCapacity(rowCount)
        
        // Populate `verticals` with the new layout.
        // This is just rows stacked on top of each other
        var currentY: CGFloat = 0
        for section in dimensions.indices {
            for row in 0..<dimensions[section] {
                let index = Index(section: section, row: row)
                let vertical = Vertical(y: currentY, height: ListView.defaultRowHeight)
                verticals[index] = vertical
                currentY = vertical.maxY
            }
        }
        
        assert(verticals.count == rowCount)
        
        self.dimensions = dimensions
        
        // Reset the scroll location to top
        bounds.origin = .zero
        contentSize.height = currentY
        setNeedsLayout()
    }
    
    /// Convenience function to convert a `Vertical` into a rectangle spanning the list view horizontally.
    private func frame(for vertical: Vertical) -> CGRect {
        return CGRect(x: bounds.minX,
                      y: vertical.y,
                      width: bounds.width,
                      height: vertical.height)
    }
    
    /// Reuse a displayed view: remove it from `displayedRows` dictionary,
    /// hide it and put into the appropriate reuse pool array.
    private func reuse(at index: Index) {
        let view = displayedRows[index]!
        view.isHidden = true
        displayedRows[index] = nil
        
        let type = type(of: view)
        let poolKey = ObjectIdentifier(type)
        
        assert(pool[poolKey] != nil, "Should create a pool for \(poolKey) when first dequeuing the row")
        pool[poolKey]!.append(view)
    }
    
    /// The equivalent of `dequeueReusableCell`, except that we use the more robust generic API.
    func dequeueRow<V: RowView>(type: V.Type, at index: Index) -> V {
        let poolKey = ObjectIdentifier(V.self)
        
        let view: V
        if pool[poolKey] == nil {
            // Just create an empty pool array for this type for later
            pool[poolKey] = []
            view = V()
        } else if pool[poolKey]!.isEmpty {
            // The pool exists but has been exhausted — need to create a new row view anyways
            view = V()
        } else {
            // The pool has a view waiting to be reused
            view = pool[poolKey]!.popLast()! as! V
        }
        
        addSubview(view)
        return view
    }
    
    /// This function either returns a row that is already visible at this index, or asks the `rowViewSource` for a new one.
    private func getView(for index: Index) -> RowView {
        guard displayedRows[index] == nil else { return displayedRows[index]! }

        // We can safely force-unwrap here because the only way `rowViewSource` is `nil`
        // is if `reload` has never been called — which means we have no rows to display
        let view: RowView = rowViewSource!(index, self)
        
        view.isHidden = false
        view.autoresizingMask = []
        // Because we perform layout manually, we need to explicitly re-enable this property
        view.translatesAutoresizingMaskIntoConstraints = true
        
        displayedRows[index] = view
        
        return view
    }
    
    override func layoutSubviews() {
        // Apple documentation states that we have to call `super` for internal bookkeeping.
        // Because this triggers Auto Layout, do it as early as possible so that our manual
        // layout stays unaffected
        super.layoutSubviews()
        
        // Query the indices of rows that are wisible within the current bounds
        // Note that the current way is suboptimal: we are performing a linear search on ordered data;
        // at some point, we will refactor this to use a binary search, which is O(log n) instead of O(n)
        let visibles: [(Index, Vertical)] = verticals.filter { $0.value.intersects(bounds) }
        
        // Reuse the views that are disappearing. Doing this first lets us reuse them right away
        // if a view of the same class reappears with a different index.
        for index in displayedRows.keys {
            if !visibles.contains(where: { $0.0 == index }) {
                reuse(at: index)
            }
        }
        
        assert(displayedRows.keys.allSatisfy { index in visibles.contains { $0.0 == index } },
               "Not all hidden rows were reused!")
        
        // Lay out the visible rows: fetch them, calculate the frame and assign it
        for (index, vertical) in visibles {
            let view = getView(for: index)
            let frame = frame(for: vertical)
            
            // This is a small optimisation: because setting `bounds` on a view calls `setNeedsLayout` on it
            // without this check all our rows would issue a layout pass on each scroll tick
            // — bad for performance!
            if view.frame != frame {
                view.frame = frame
            }
        }
        
        assert(visibles.allSatisfy { displayedRows.keys.contains($0.0) }, "Not all visible rows are actually displayed!")
        assert(displayedRows.allSatisfy { $0.value.isHidden == false }, "Not all visible rows are unhidden!")
        
        // Check the number of subviews — you will see that it remains the same
        // no matter how many rows the list view is actually displaying
        print(subviews.count)
    }
}

extension ListView.Index: Comparable {
    
    /// List view indices are totally ordered, meaning they always compare as `<`, `=` or `>`, and thus are `Comparable`.
    /// An index is smaller if it appears in an earlier section or if it appears earlier in the same section.
    static func < (lhs: ListView.Index, rhs: ListView.Index) -> Bool {
        lhs.section < rhs.section || (lhs.section == rhs.section && lhs.row < rhs.row)
    }
}
