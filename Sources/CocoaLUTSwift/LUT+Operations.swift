import Foundation

extension LUT {
    public func swizzling1DChannels(method: LUT1D.SwizzleMethod, strictness: Bool = false) -> LUT? {
        let lut3d = LUT3D(lattice: self)
        guard let result3d = lut3d.swizzling1DChannels(method: method, strictness: strictness) else {
            return nil
        }
        return result3d.asLUT()
    }
}
