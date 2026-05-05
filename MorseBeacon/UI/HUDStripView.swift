import SwiftUI

#if SWIFT_PACKAGE
  import Core
#endif

/// 88pt-tall fixed-brightness strip at the top of `BeaconView` showing the
/// source message (line 1) and its Morse rendering (line 2), with the
/// current character/element highlighted in amber per FR-14.
///
/// Per R4: highlight strictly follows the tick. During gap ticks (isOn ==
/// false) **both** lines un-highlight. Auto-scroll viewport holds at the
/// most-recent highlighted position so it doesn't drift to the start
/// during gaps.
///
/// Per FR-15: scrolling is instantaneous at character boundaries — no
/// animation that could compete with the flash timing visually.
struct HUDStripView: View {

  let message: String
  let elements: [TimedElement]
  let currentTick: ScheduleTick

  /// Pre-computed Morse rendering and column lookup. Derived once from
  /// `elements`; doesn't change per tick.
  private let line2: MorseRenderer.Line2

  /// Last known highlight positions, used to anchor the scroll viewport
  /// during gap ticks. Updated only on `isOn` ticks (R4).
  @State private var lastCharIndex: Int = 0
  @State private var lastColumn: Int = 0

  init(message: String, elements: [TimedElement], currentTick: ScheduleTick) {
    self.message = message
    self.elements = elements
    self.currentTick = currentTick
    self.line2 = MorseRenderer.renderLine2(elements)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Line1View(
        text: message,
        highlightedIndex: highlightedCharIndex,
        scrollTargetIndex: lastCharIndex
      )
      Line2View(
        text: line2.string,
        highlightedColumn: highlightedColumn,
        scrollTargetColumn: lastColumn
      )
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: Theme.hudStripHeight)
    .background(Theme.hudStripBackground)
    .onChange(of: currentTick) { _, new in
      // Update last-known positions only on isOn ticks (R4).
      guard new.isOn else { return }
      if let i = new.sourceCharIndex {
        lastCharIndex = i
      }
      if let col = line2.elementIndexToColumn[new.elementIndexInMessage] {
        lastColumn = col
      }
    }
  }

  /// Current highlighted character on Line 1. Nil during gap ticks.
  private var highlightedCharIndex: Int? {
    currentTick.isOn ? currentTick.sourceCharIndex : nil
  }

  /// Current highlighted column on Line 2. Nil during gap ticks.
  private var highlightedColumn: Int? {
    guard currentTick.isOn else { return nil }
    return line2.elementIndexToColumn[currentTick.elementIndexInMessage]
  }
}

// MARK: - Line views

private struct Line1View: View {
  let text: String
  let highlightedIndex: Int?
  let scrollTargetIndex: Int

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          ForEach(Array(text.enumerated()), id: \.offset) { i, c in
            Text(String(c))
              .id(i)
              .padding(.horizontal, 2)
              .background(highlightedIndex == i ? Theme.hudHighlightBackground : .clear)
              .foregroundStyle(
                highlightedIndex == i ? Theme.hudHighlightForeground : Theme.hudText)
          }
        }
        .font(.system(size: 28, weight: .semibold, design: .monospaced))
      }
      .scrollDisabled(true)
      .onChange(of: scrollTargetIndex) { _, new in
        scrollInstantly(proxy: proxy, to: new)
      }
      .onAppear {
        scrollInstantly(proxy: proxy, to: scrollTargetIndex)
      }
    }
  }

  private func scrollInstantly(proxy: ScrollViewProxy, to id: Int) {
    var t = Transaction()
    t.disablesAnimations = true
    withTransaction(t) {
      proxy.scrollTo(id, anchor: .center)
    }
  }
}

private struct Line2View: View {
  let text: String
  let highlightedColumn: Int?
  let scrollTargetColumn: Int

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          ForEach(Array(text.enumerated()), id: \.offset) { col, c in
            Text(String(c))
              .id(col)
              .padding(.horizontal, 1)
              .background(highlightedColumn == col ? Theme.hudHighlightBackground : .clear)
              .foregroundStyle(
                highlightedColumn == col ? Theme.hudHighlightForeground : Theme.hudText)
          }
        }
        .font(.system(size: 24, design: .monospaced))
      }
      .scrollDisabled(true)
      .onChange(of: scrollTargetColumn) { _, new in
        scrollInstantly(proxy: proxy, to: new)
      }
      .onAppear {
        scrollInstantly(proxy: proxy, to: scrollTargetColumn)
      }
    }
  }

  private func scrollInstantly(proxy: ScrollViewProxy, to id: Int) {
    var t = Transaction()
    t.disablesAnimations = true
    withTransaction(t) {
      proxy.scrollTo(id, anchor: .center)
    }
  }
}
