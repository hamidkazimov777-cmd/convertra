import SwiftUI

struct WaveformShape: Shape {
    let samples: [Float]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else { return path }
        
        let width = rect.width / CGFloat(samples.count)
        let midY = rect.midY
        let height = rect.height
        
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * width
            let sampleHeight = CGFloat(sample) * height
            
            let barRect = CGRect(
                x: x,
                y: midY - sampleHeight / 2,
                width: max(1, width - 1),
                height: max(2, sampleHeight)
            )
            
            path.addRoundedRect(in: barRect, cornerSize: CGSize(width: 2, height: 2))
        }
        
        return path
    }
}
