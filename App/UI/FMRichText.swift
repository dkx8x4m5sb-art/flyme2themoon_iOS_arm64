//
//  FMRichText.swift
//  对话文本里的 #rrggbb / #n 是原版的颜色标记（比如 #cffc600 金色高亮），
//  这里把它拆成 AttributedString，逐段上色。
//

import SwiftUI

struct FMRichText: View {
    let raw: String

    var body: some View {
        Text(Self.attributed(raw))
    }

    static func attributed(_ raw: String) -> AttributedString {
        var result = AttributedString()
        var color: Color?
        var buffer = ""

        func flush() {
            guard !buffer.isEmpty else { return }
            var piece = AttributedString(buffer)
            if let color { piece.foregroundColor = color }
            result.append(piece)
            buffer.removeAll()
        }

        var index = raw.startIndex
        while index < raw.endIndex {
            if raw[index] == "#" {
                let tail = raw[index...]
                if tail.hasPrefix("#n") {
                    flush()
                    color = nil
                    index = raw.index(index, offsetBy: 2)
                    continue
                }
                if tail.count >= 7 {
                    let hexStart = raw.index(after: index)
                    let hexEnd = raw.index(hexStart, offsetBy: 6)
                    let hex = String(raw[hexStart..<hexEnd])
                    if hex.count == 6, hex.allSatisfy({ $0.isHexDigit }), let parsed = Color(fmHex: hex) {
                        flush()
                        color = parsed
                        index = hexEnd
                        continue
                    }
                }
            }
            buffer.append(raw[index])
            index = raw.index(after: index)
        }
        flush()
        return result
    }
}

extension Color {
    init?(fmHex: String) {
        var value: UInt64 = 0
        guard Scanner(string: fmHex).scanHexInt64(&value) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255.0,
                  green: Double((value >> 8) & 0xFF) / 255.0,
                  blue: Double(value & 0xFF) / 255.0)
    }
}
