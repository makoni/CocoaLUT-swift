import Foundation

extension LUT {
    public func swizzling1DChannels(method: LUT1D.SwizzleMethod, strictness: Bool = false) -> LUT? {
        let lut3d = LUT3D(lattice: self)
        guard let result3d = lut3d.swizzling1DChannels(method: method, strictness: strictness) else {
            return nil
        }
        return result3d.asLUT()
    }
    
    public func offset(with color: LUTColor) -> LUT {
        mapColors { $0 + color }
    }
    
    public func changingStrength(_ strength: Double) -> LUT {
        precondition(strength <= 1.0, "Strength cannot be greater than 1.0")
        if strength == 1.0 { return self }
        
        var newLUT = LUT(size: size, inputLowerBound: inputLowerBound, inputUpperBound: inputUpperBound)
        cloneMetadata(into: &newLUT)
        
        loop { r, g, b in
            let identity = identityColorAt(r: Double(r), g: Double(g), b: Double(b))
            let color = colorAt(r: r, g: g, b: b)
            let lerped = identity.lerp(to: color, amount: strength)
            newLUT.setColor(lerped, r: r, g: g, b: b)
        }
        return newLUT
    }
    
    public func inverted() -> LUT {
        mapColors { $0.inverted(minimumValue: 0, maximumValue: 1) }
    }
}
