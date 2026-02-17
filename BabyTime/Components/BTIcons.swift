//
//  BTIcons.swift
//  BabyTime
//
//  Custom icon shapes translated from filled-outline SVG designs.
//  Each shape scales proportionally to fit its rect, preserving aspect ratio.
//

import SwiftUI

// MARK: - Nursing Icon (22×18 viewBox)

struct NursingIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let viewW: CGFloat = 22
        let viewH: CGFloat = 18
        let scale = min(rect.width / viewW, rect.height / viewH)
        let dx = (rect.width - viewW * scale) / 2
        let dy = (rect.height - viewH * scale) / 2

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scale + dx, y: y * scale + dy)
        }

        var path = Path()

        // Subpath 1: left drop outer contour
        path.move(to: pt(9.618, 0.996))
        path.addCurve(to: pt(12.777, 4.874), control1: pt(10.602, 1.973), control2: pt(11.811, 3.323))
        path.addCurve(to: pt(14.5, 10.092), control1: pt(13.739, 6.417), control2: pt(14.5, 8.222))
        path.addCurve(to: pt(7.25, 17.5), control1: pt(14.5, 13.707), control2: pt(11.78, 17.5))
        path.addCurve(to: pt(0, 10.092), control1: pt(2.72, 17.5), control2: pt(0, 13.707))
        path.addCurve(to: pt(1.723, 4.874), control1: pt(0, 8.222), control2: pt(0.761, 6.417))
        path.addCurve(to: pt(4.882, 0.996), control1: pt(2.689, 3.323), control2: pt(3.898, 1.973))
        path.addCurve(to: pt(9.618, 0.996), control1: pt(6.218, -0.332), control2: pt(8.282, -0.332))
        path.closeSubpath()

        // Subpath 2: left drop inner contour
        path.move(to: pt(5.939, 2.06))
        path.addCurve(to: pt(2.996, 5.668), control1: pt(5.001, 2.992), control2: pt(3.879, 4.25))
        path.addCurve(to: pt(1.5, 10.092), control1: pt(2.108, 7.092), control2: pt(1.5, 8.616))
        path.addCurve(to: pt(7.25, 16), control1: pt(1.5, 13.042), control2: pt(3.703, 16))
        path.addCurve(to: pt(13, 10.092), control1: pt(10.797, 16), control2: pt(13, 13.042))
        path.addCurve(to: pt(11.504, 5.668), control1: pt(13, 8.616), control2: pt(12.392, 7.092))
        path.addCurve(to: pt(8.561, 2.06), control1: pt(10.621, 4.25), control2: pt(9.499, 2.992))
        path.addCurve(to: pt(5.939, 2.06), control1: pt(7.81, 1.313), control2: pt(6.69, 1.313))
        path.closeSubpath()

        // Subpath 3: right drop
        path.move(to: pt(12.939, 2.06))
        path.addCurve(to: pt(11.878, 2.056), control1: pt(12.645, 2.352), control2: pt(12.17, 2.35))
        path.addCurve(to: pt(11.882, 0.996), control1: pt(11.586, 1.763), control2: pt(11.588, 1.288))
        path.addCurve(to: pt(16.618, 0.996), control1: pt(13.218, -0.332), control2: pt(15.282, -0.332))
        path.addCurve(to: pt(19.777, 4.874), control1: pt(17.602, 1.973), control2: pt(18.811, 3.323))
        path.addCurve(to: pt(21.5, 10.092), control1: pt(20.739, 6.417), control2: pt(21.5, 8.222))
        path.addCurve(to: pt(14.25, 17.5), control1: pt(21.5, 13.707), control2: pt(18.78, 17.5))
        path.addCurve(to: pt(13.5, 16.75), control1: pt(13.836, 17.5), control2: pt(13.5, 17.164))
        path.addCurve(to: pt(14.25, 16), control1: pt(13.5, 16.336), control2: pt(13.836, 16))
        path.addCurve(to: pt(20, 10.092), control1: pt(17.797, 16), control2: pt(20, 13.042))
        path.addCurve(to: pt(18.504, 5.668), control1: pt(20, 8.616), control2: pt(19.392, 7.092))
        path.addCurve(to: pt(15.561, 2.06), control1: pt(17.621, 4.25), control2: pt(16.499, 2.992))
        path.addCurve(to: pt(12.939, 2.06), control1: pt(14.81, 1.313), control2: pt(13.69, 1.313))
        path.closeSubpath()

        return path
    }
}

// MARK: - Bottle Icon (14×22 viewBox)

struct BottleIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let viewW: CGFloat = 14
        let viewH: CGFloat = 22
        let scale = min(rect.width / viewW, rect.height / viewH)
        let dx = (rect.width - viewW * scale) / 2
        let dy = (rect.height - viewH * scale) / 2

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scale + dx, y: y * scale + dy)
        }

        var path = Path()

        // Subpath 1: outer contour
        path.move(to: pt(6.014, 0.122111))
        path.addCurve(to: pt(6.761, 0.000111441), control1: pt(6.224, 0.0551114), control2: pt(6.481, -0.00288856))
        path.addCurve(to: pt(7.461, 0.122111), control1: pt(7.027, 0.00311144), control2: pt(7.268, 0.0611114))
        path.addCurve(to: pt(9.128, 4.12411), control1: pt(9.151, 0.653111), control2: pt(9.952, 2.56111))
        path.addCurve(to: pt(9.121, 5.01011), control1: pt(8.94, 4.48111), control2: pt(8.996, 4.77211))
        path.addCurve(to: pt(9.415, 5.23411), control1: pt(9.139, 5.04411), control2: pt(9.21, 5.12811))
        path.addCurve(to: pt(10.071, 5.48711), control1: pt(9.609, 5.33511), control2: pt(9.838, 5.41311))
        path.addCurve(to: pt(12.279, 7.36211), control1: pt(11.251, 5.86111), control2: pt(11.939, 6.56911))
        path.addCurve(to: pt(12.523, 9.18311), control1: pt(12.563, 8.02211), control2: pt(12.583, 8.68911))
        path.addCurve(to: pt(12.619, 9.46211), control1: pt(12.55, 9.25811), control2: pt(12.582, 9.35111))
        path.addCurve(to: pt(12.979, 10.7341), control1: pt(12.718, 9.76411), control2: pt(12.849, 10.1971))
        path.addCurve(to: pt(13.5, 15.0031), control1: pt(13.239, 11.8061), control2: pt(13.5, 13.3041))
        path.addCurve(to: pt(13.191, 18.2781), control1: pt(13.5, 16.2281), control2: pt(13.364, 17.3481))
        path.addLine(to: pt(13.166, 18.4161))
        path.addCurve(to: pt(12.064, 20.8651), control1: pt(12.983, 19.4071), control2: pt(12.832, 20.2281))
        path.addCurve(to: pt(10.709, 21.4351), control1: pt(11.654, 21.2061), control2: pt(11.209, 21.3631))
        path.addCurve(to: pt(9.09, 21.5001), control1: pt(10.254, 21.5011), control2: pt(9.711, 21.5011))
        path.addLine(to: pt(4.41, 21.5001))
        path.addCurve(to: pt(2.791, 21.4351), control1: pt(3.789, 21.5011), control2: pt(3.246, 21.5011))
        path.addCurve(to: pt(1.436, 20.8651), control1: pt(2.291, 21.3631), control2: pt(1.846, 21.2061))
        path.addCurve(to: pt(0.334, 18.4161), control1: pt(0.668, 20.2281), control2: pt(0.517, 19.4071))
        path.addLine(to: pt(0.309, 18.2781))
        path.addCurve(to: pt(0, 15.0031), control1: pt(0.136, 17.3481), control2: pt(0, 16.2281))
        path.addCurve(to: pt(0.521, 10.7341), control1: pt(0, 13.3041), control2: pt(0.261, 11.8061))
        path.addCurve(to: pt(0.881, 9.46211), control1: pt(0.651, 10.1971), control2: pt(0.782, 9.76411))
        path.addCurve(to: pt(0.982, 9.16811), control1: pt(0.92, 9.34311), control2: pt(0.955, 9.24511))
        path.addCurve(to: pt(3.826, 5.37811), control1: pt(0.775, 7.42411), control2: pt(1.849, 5.76311))
        path.addCurve(to: pt(4.463, 4.89211), control1: pt(4.157, 5.26611), control2: pt(4.347, 5.11111))
        path.addCurve(to: pt(4.523, 4.63511), control1: pt(4.513, 4.79711), control2: pt(4.528, 4.72111))
        path.addCurve(to: pt(4.346, 4.12411), control1: pt(4.516, 4.53511), control2: pt(4.478, 4.37411))
        path.addCurve(to: pt(6.014, 0.122111), control1: pt(3.522, 2.56111), control2: pt(4.324, 0.653111))
        path.closeSubpath()

        // Subpath 2: body inner contour
        path.move(to: pt(2.281, 10.0081))
        path.addCurve(to: pt(1.979, 11.0881), control1: pt(2.196, 10.2731), control2: pt(2.088, 10.6391))
        path.addCurve(to: pt(1.5, 15.0031), control1: pt(1.739, 12.0771), control2: pt(1.5, 13.4531))
        path.addCurve(to: pt(1.783, 18.0041), control1: pt(1.5, 16.1191), control2: pt(1.624, 17.1461))
        path.addCurve(to: pt(2.394, 19.7121), control1: pt(2.005, 19.1981), control2: pt(2.085, 19.4551))
        path.addCurve(to: pt(3.005, 19.9501), control1: pt(2.54, 19.8331), control2: pt(2.704, 19.9071))
        path.addCurve(to: pt(4.458, 20.0001), control1: pt(3.34, 19.9991), control2: pt(3.775, 20.0001))
        path.addLine(to: pt(9.042, 20.0001))
        path.addCurve(to: pt(10.495, 19.9501), control1: pt(9.725, 20.0001), control2: pt(10.16, 19.9991))
        path.addCurve(to: pt(11.106, 19.7121), control1: pt(10.796, 19.9071), control2: pt(10.96, 19.8331))
        path.addCurve(to: pt(11.717, 18.0041), control1: pt(11.415, 19.4551), control2: pt(11.495, 19.1981))
        path.addCurve(to: pt(11.803, 17.5001), control1: pt(11.747, 17.8421), control2: pt(11.776, 17.6731))
        path.addLine(to: pt(9.75, 17.5001))
        path.addCurve(to: pt(9, 16.7501), control1: pt(9.336, 17.5001), control2: pt(9, 17.1641))
        path.addCurve(to: pt(9.75, 16.0001), control1: pt(9, 16.3351), control2: pt(9.336, 16.0001))
        path.addLine(to: pt(11.968, 16.0001))
        path.addCurve(to: pt(12, 15.0031), control1: pt(11.988, 15.6771), control2: pt(12, 15.3441))
        path.addCurve(to: pt(11.927, 13.5001), control1: pt(12, 14.4791), control2: pt(11.973, 13.9751))
        path.addLine(to: pt(9.75, 13.5001))
        path.addCurve(to: pt(9, 12.7501), control1: pt(9.336, 13.5001), control2: pt(9, 13.1641))
        path.addCurve(to: pt(9.75, 12.0001), control1: pt(9, 12.3351), control2: pt(9.336, 12.0001))
        path.addLine(to: pt(11.716, 12.0001))
        path.addCurve(to: pt(11.521, 11.0881), control1: pt(11.655, 11.6691), control2: pt(11.588, 11.3631))
        path.addCurve(to: pt(11.219, 10.0081), control1: pt(11.412, 10.6391), control2: pt(11.304, 10.2731))
        path.addLine(to: pt(2.281, 10.0081))
        path.closeSubpath()

        // Subpath 3: nipple inner contour
        path.move(to: pt(6.746, 1.50011))
        path.addCurve(to: pt(6.464, 1.55311), control1: pt(6.678, 1.49911), control2: pt(6.586, 1.51411))
        path.addCurve(to: pt(5.673, 3.42511), control1: pt(5.653, 1.80711), control2: pt(5.293, 2.70311))
        path.addCurve(to: pt(6.02, 4.53811), control1: pt(5.867, 3.79211), control2: pt(5.995, 4.16111))
        path.addCurve(to: pt(5.789, 5.59311), control1: pt(6.045, 4.92811), control2: pt(5.956, 5.27811))
        path.addCurve(to: pt(4.24, 6.82111), control1: pt(5.433, 6.26611), control2: pt(4.85, 6.62711))
        path.addCurve(to: pt(4.147, 6.84411), control1: pt(4.21, 6.83011), control2: pt(4.179, 6.83811))
        path.addCurve(to: pt(2.47, 8.50811), control1: pt(3.14, 7.02711), control2: pt(2.563, 7.70711))
        path.addLine(to: pt(11.04, 8.50811))
        path.addCurve(to: pt(10.9, 7.95311), control1: pt(11.021, 8.32611), control2: pt(10.979, 8.13511))
        path.addCurve(to: pt(9.618, 6.91711), control1: pt(10.739, 7.57711), control2: pt(10.399, 7.16411))
        path.addCurve(to: pt(8.723, 6.56511), control1: pt(9.385, 6.84311), control2: pt(9.044, 6.73211))
        path.addCurve(to: pt(7.795, 5.71111), control1: pt(8.412, 6.40411), control2: pt(8.023, 6.14111))
        path.addCurve(to: pt(7.802, 3.42511), control1: pt(7.486, 5.12611), control2: pt(7.338, 4.30411))
        path.addCurve(to: pt(7.011, 1.55311), control1: pt(8.182, 2.70311), control2: pt(7.821, 1.80711))
        path.addCurve(to: pt(6.746, 1.50011), control1: pt(6.891, 1.51511), control2: pt(6.807, 1.50111))
        path.closeSubpath()

        return path
    }
}

// MARK: - Sleep Icon (18×18 viewBox, even-odd fill)

struct SleepIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let viewW: CGFloat = 18
        let viewH: CGFloat = 18
        let scale = min(rect.width / viewW, rect.height / viewH)
        let dx = (rect.width - viewW * scale) / 2
        let dy = (rect.height - viewH * scale) / 2

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scale + dx, y: y * scale + dy)
        }

        var path = Path()

        // Subpath 1: large Z (top-left)
        path.move(to: pt(7.75004, 9.50005))
        path.addLine(to: pt(0.75, 9.50005))
        path.addCurve(to: pt(0.0699499, 9.06005), control1: pt(0.46, 9.50005), control2: pt(0.18995, 9.33005))
        path.addCurve(to: pt(0.18994, 8.26005), control1: pt(-0.0500501, 8.79005), control2: pt(-0.01006, 8.48005))
        path.addLine(to: pt(6.09998, 1.5))
        path.addLine(to: pt(0.75, 1.5))
        path.addCurve(to: pt(0, 0.75), control1: pt(0.34, 1.5), control2: pt(0, 1.16))
        path.addCurve(to: pt(0.75, 0), control1: pt(0, 0.34), control2: pt(0.34, 0))
        path.addLine(to: pt(7.75004, 0))
        path.addCurve(to: pt(8.43004, 0.44001), control1: pt(8.04004, 0), control2: pt(8.31004, 0.17001))
        path.addCurve(to: pt(8.31004, 1.24006), control1: pt(8.55004, 0.71001), control2: pt(8.51004, 1.02006))
        path.addLine(to: pt(2.40003, 8.00005))
        path.addLine(to: pt(7.75004, 8.00005))
        path.addCurve(to: pt(8.50004, 8.75005), control1: pt(8.16004, 8.00005), control2: pt(8.50004, 8.34005))
        path.addCurve(to: pt(7.75004, 9.50005), control1: pt(8.50004, 9.16005), control2: pt(8.16004, 9.50005))
        path.closeSubpath()

        // Subpath 2: small z (bottom-left)
        path.move(to: pt(6.75, 17.5))
        path.addLine(to: pt(2.75, 17.5))
        path.addCurve(to: pt(2.06006, 17.0401), control1: pt(2.45, 17.5), control2: pt(2.17006, 17.3201))
        path.addCurve(to: pt(2.21997, 16.2201), control1: pt(1.94006, 16.7601), control2: pt(2.00997, 16.4401))
        path.addLine(to: pt(4.93994, 13.5))
        path.addLine(to: pt(2.75, 13.5))
        path.addCurve(to: pt(2, 12.75), control1: pt(2.34, 13.5), control2: pt(2, 13.16))
        path.addCurve(to: pt(2.75, 12), control1: pt(2, 12.34), control2: pt(2.34, 12))
        path.addLine(to: pt(6.75, 12))
        path.addCurve(to: pt(7.43994, 12.4601), control1: pt(7.05004, 12), control2: pt(7.32994, 12.1801))
        path.addCurve(to: pt(7.28004, 13.2801), control1: pt(7.55994, 12.7401), control2: pt(7.49004, 13.0601))
        path.addLine(to: pt(4.56006, 16))
        path.addLine(to: pt(6.75, 16))
        path.addCurve(to: pt(7.50004, 16.75), control1: pt(7.16004, 16), control2: pt(7.50004, 16.34))
        path.addCurve(to: pt(6.75, 17.5), control1: pt(7.50004, 17.16), control2: pt(7.16004, 17.5))
        path.closeSubpath()

        // Subpath 3: medium Z (right)
        path.move(to: pt(10.75, 12.5))
        path.addLine(to: pt(16.75, 12.5))
        path.addCurve(to: pt(17.5, 11.75), control1: pt(17.16, 12.5), control2: pt(17.5, 12.16))
        path.addCurve(to: pt(16.75, 11), control1: pt(17.5, 11.34), control2: pt(17.16, 11))
        path.addLine(to: pt(12.56, 11))
        path.addLine(to: pt(17.28, 6.28003))
        path.addCurve(to: pt(17.4399, 5.46003), control1: pt(17.49, 6.06003), control2: pt(17.5599, 5.74003))
        path.addCurve(to: pt(16.75, 5), control1: pt(17.3299, 5.18003), control2: pt(17.05, 5))
        path.addLine(to: pt(10.75, 5))
        path.addCurve(to: pt(10, 5.75), control1: pt(10.34, 5), control2: pt(10, 5.34))
        path.addCurve(to: pt(10.75, 6.50005), control1: pt(10, 6.16), control2: pt(10.34, 6.50005))
        path.addLine(to: pt(14.9399, 6.50005))
        path.addLine(to: pt(10.2199, 11.22))
        path.addCurve(to: pt(10.06, 12.04), control1: pt(10.0099, 11.44), control2: pt(9.94004, 11.76))
        path.addCurve(to: pt(10.75, 12.5), control1: pt(10.17, 12.32), control2: pt(10.45, 12.5))
        path.closeSubpath()

        return path
    }
}

// MARK: - BTIcon View

struct BTIcon: View {
    enum Kind {
        case nursing
        case bottle
        case sleep
    }

    let kind: Kind

    var body: some View {
        switch kind {
        case .nursing:
            NursingIconShape()
                .fill()
                .aspectRatio(22.0 / 18.0, contentMode: .fit)
        case .bottle:
            BottleIconShape()
                .fill()
                .aspectRatio(14.0 / 22.0, contentMode: .fit)
        case .sleep:
            SleepIconShape()
                .fill(style: FillStyle(eoFill: true))
                .aspectRatio(1, contentMode: .fit)
        }
    }
}

// MARK: - Preview

#Preview("All Icons") {
    HStack(spacing: 32) {
        VStack {
            BTIcon(kind: .nursing)
                .foregroundStyle(Color.btFeedAccent)
                .frame(height: 32)
            Text("Nursing").font(.caption)
        }
        VStack {
            BTIcon(kind: .bottle)
                .foregroundStyle(Color.btFeedAccent)
                .frame(height: 32)
            Text("Bottle").font(.caption)
        }
        VStack {
            BTIcon(kind: .sleep)
                .foregroundStyle(Color.btSleepAccent)
                .frame(height: 32)
            Text("Sleep").font(.caption)
        }
    }
    .padding()
}

#Preview("Icon Sizes") {
    VStack(spacing: 20) {
        ForEach([12, 16, 24, 32, 48], id: \.self) { size in
            HStack(spacing: 16) {
                Text("\(size)pt").frame(width: 40, alignment: .trailing).font(.caption)
                BTIcon(kind: .nursing)
                    .foregroundStyle(Color.btFeedAccent)
                    .frame(height: CGFloat(size))
                BTIcon(kind: .bottle)
                    .foregroundStyle(Color.btFeedAccent)
                    .frame(height: CGFloat(size))
                BTIcon(kind: .sleep)
                    .foregroundStyle(Color.btSleepAccent)
                    .frame(height: CGFloat(size))
            }
        }
    }
    .padding()
}
