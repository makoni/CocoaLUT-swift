import Foundation

extension LUT {
    public func equalsLUTEssence(comparingTo other: LUT, compareType: Bool = true, compareSize: Bool = true, compareInputBounds: Bool = true) -> Bool {
        // In Swift implementation, we treat all LUTs as 3D LUTs (size x size x size).
        // So compareType is effectively always true if they are both LUT structs.
        
        if compareSize && self.size != other.size {
            return false
        }
        
        if compareInputBounds {
            if abs(self.inputLowerBound - other.inputLowerBound) > 1e-6 ||
               abs(self.inputUpperBound - other.inputUpperBound) > 1e-6 {
                return false
            }
        }
        
        return true
    }

    public func symmetricalMeanAbsolutePercentageError(comparingTo other: LUT) -> LUTColor {
        if !equalsLUTEssence(comparingTo: other) {
            return LUTColor(red: 1000000, green: 1000000, blue: 1000000)
        }
        
        var redAbsoluteError = 0.0
        var greenAbsoluteError = 0.0
        var blueAbsoluteError = 0.0
        
        let numPoints = Double(size * size * size)
        
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let c1 = colorAt(r: r, g: g, b: b)
                    let c2 = other.colorAt(r: r, g: g, b: b)
                    
                    let redAdd = abs(c1.red - c2.red) / (c1.red + c2.red)
                    let greenAdd = abs(c1.green - c2.green) / (c1.green + c2.green)
                    let blueAdd = abs(c1.blue - c2.blue) / (c1.blue + c2.blue)
                    
                    redAbsoluteError += redAdd.isFinite ? redAdd : 0
                    greenAbsoluteError += greenAdd.isFinite ? greenAdd : 0
                    blueAbsoluteError += blueAdd.isFinite ? blueAdd : 0
                }
            }
        }
        
        return LUTColor(red: redAbsoluteError / numPoints,
                        green: greenAbsoluteError / numPoints,
                        blue: blueAbsoluteError / numPoints)
    }
    
    public func averageAbsoluteError(comparingTo other: LUT) -> LUTColor {
        if !equalsLUTEssence(comparingTo: other) {
            return LUTColor(red: 1000000, green: 1000000, blue: 1000000)
        }
        
        var redError = 0.0
        var greenError = 0.0
        var blueError = 0.0
        
        let numPoints = Double(size * size * size)
        
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let c1 = colorAt(r: r, g: g, b: b)
                    let c2 = other.colorAt(r: r, g: g, b: b)
                    
                    let diffRed = abs(c1.red - c2.red)
                    let diffGreen = abs(c1.green - c2.green)
                    let diffBlue = abs(c1.blue - c2.blue)
                    
                    redError += diffRed.isFinite ? diffRed : 0
                    greenError += diffGreen.isFinite ? diffGreen : 0
                    blueError += diffBlue.isFinite ? diffBlue : 0
                }
            }
        }
        
        return LUTColor(red: redError / numPoints,
                        green: greenError / numPoints,
                        blue: blueError / numPoints)
    }
    
    public func maximumAbsoluteError(comparingTo other: LUT) -> LUTColor {
        if !equalsLUTEssence(comparingTo: other) {
            return LUTColor(red: 1000000, green: 1000000, blue: 1000000)
        }
        
        var redMaxError = 0.0
        var greenMaxError = 0.0
        var blueMaxError = 0.0
        
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let c1 = colorAt(r: r, g: g, b: b)
                    let c2 = other.colorAt(r: r, g: g, b: b)
                    
                    let diffRed = abs(c1.red - c2.red)
                    let diffGreen = abs(c1.green - c2.green)
                    let diffBlue = abs(c1.blue - c2.blue)
                    
                    if diffRed > redMaxError { redMaxError = diffRed }
                    if diffGreen > greenMaxError { greenMaxError = diffGreen }
                    if diffBlue > blueMaxError { blueMaxError = diffBlue }
                }
            }
        }
        
        return LUTColor(red: redMaxError, green: greenMaxError, blue: blueMaxError)
    }
}
