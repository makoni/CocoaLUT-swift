#if canImport(AppKit)
import AppKit
import AVFoundation
import QuartzCore

@MainActor
public final class LUTPreviewView: NSView {
    public var lut: LUT? {
        didSet {
            cachedProcessedImage = nil
            scheduleImageUpdate()
            updateVideoFilters()
        }
    }

    private var internalMaskAmount: CGFloat = 0.5
    public var maskAmount: CGFloat {
        get { internalMaskAmount }
        set {
            let clamped = max(0, min(newValue, 1))
            guard clamped != internalMaskAmount else { return }
            internalMaskAmount = clamped
            updateMaskFrames()
            needsLayout = true
        }
    }

    public var previewImage: NSImage? {
        didSet {
            if previewImage != nil {
                cachedProcessedImage = nil
                // Setting a still image hides any active video, mirroring ObjC `setPreviewImage:`.
                if videoURL != nil {
                    videoURL = nil
                }
            }
            scheduleImageUpdate()
        }
    }

    /// URL of a video to play under the LUT.
    /// Setting non-nil starts playback (looping, muted) and switches the view to video mode.
    /// Setting nil pauses the player and returns to still-image mode.
    /// Mirrors ObjC `LUTPreviewView.videoURL` (LUTPreviewView.h:34).
    public var videoURL: URL? {
        didSet {
            applyVideoURL()
        }
    }

    /// AVPlayer driving both video layers. Available even before a URL is set.
    /// Mirrors ObjC `LUTPreviewView.videoPlayer` (LUTPreviewView.h:39).
    public private(set) var videoPlayer: AVPlayer

    /// `true` while a video is loaded. Mirrors ObjC `LUTPreviewView.isVideo` (LUTPreviewView.h:44).
    public private(set) var isVideo: Bool = false

    public private(set) var originalLayer = CALayer()
    public private(set) var processedLayer = CALayer()

    /// AVPlayerLayer that renders the LUT-processed video. Mirrors ObjC `lutVideoLayer`.
    public private(set) var lutVideoLayer: AVPlayerLayer
    /// AVPlayerLayer that renders the original (non-LUT) video. Mirrors ObjC `normalVideoLayer`.
    public private(set) var normalVideoLayer: AVPlayerLayer

    private let maskLayer = CALayer()
    private let processedContainerLayer = CALayer()
    private let videoMaskLayer = CALayer()
    private let borderLayer = CALayer()
    private var cachedProcessedImage: NSImage?
    nonisolated(unsafe) private var endOfPlaybackObserver: NSObjectProtocol?

    public override init(frame frameRect: NSRect) {
        let player = AVPlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        self.videoPlayer = player
        self.lutVideoLayer = AVPlayerLayer(player: player)
        self.normalVideoLayer = AVPlayerLayer(player: player)
        super.init(frame: frameRect)
        configureLayers()
    }

    public required init?(coder: NSCoder) {
        let player = AVPlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        self.videoPlayer = player
        self.lutVideoLayer = AVPlayerLayer(player: player)
        self.normalVideoLayer = AVPlayerLayer(player: player)
        super.init(coder: coder)
        configureLayers()
    }

    deinit {
        if let observer = endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let bounds = self.bounds
        originalLayer.frame = bounds
        processedLayer.frame = bounds
        normalVideoLayer.frame = bounds
        lutVideoLayer.frame = bounds
        updateMaskFrames(within: bounds)
        CATransaction.commit()
    }

    private func configureLayers() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.backgroundColor = NSColor.black.cgColor
        layerUsesCoreImageFilters = true

        originalLayer.contentsGravity = .resizeAspect
        originalLayer.masksToBounds = true

        processedContainerLayer.masksToBounds = true

        processedLayer.contentsGravity = .resizeAspect
        processedLayer.masksToBounds = true

        maskLayer.backgroundColor = NSColor.white.cgColor
        maskLayer.anchorPoint = .zero
        maskLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "transform": NSNull()
        ]
        processedLayer.mask = maskLayer

        videoMaskLayer.backgroundColor = NSColor.white.cgColor
        videoMaskLayer.anchorPoint = .zero
        videoMaskLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "transform": NSNull()
        ]

        borderLayer.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.5).cgColor
        borderLayer.zPosition = 1

        normalVideoLayer.backgroundColor = NSColor.black.cgColor
        lutVideoLayer.backgroundColor = NSColor.black.cgColor

        layer?.addSublayer(originalLayer)
        processedContainerLayer.addSublayer(processedLayer)
        layer?.addSublayer(processedContainerLayer)
        layer?.addSublayer(lutVideoLayer)
        layer?.addSublayer(normalVideoLayer)
        layer?.addSublayer(borderLayer)

        setupPlaybackLayers()
    }

    /// Mirrors ObjC `-setupPlaybackLayers` (LUTPreviewView.m:278-293):
    /// toggles visibility of image vs. video layers based on `isVideo` and
    /// re-attaches the mask to whichever non-LUT layer is currently active.
    private func setupPlaybackLayers() {
        lutVideoLayer.isHidden = !isVideo
        normalVideoLayer.isHidden = !isVideo
        originalLayer.isHidden = isVideo
        processedLayer.isHidden = isVideo

        if isVideo {
            normalVideoLayer.mask = videoMaskLayer
        } else {
            normalVideoLayer.mask = nil
        }
    }

    private func applyVideoURL() {
        if let observer = endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfPlaybackObserver = nil
        }

        if let url = videoURL {
            let item = AVPlayerItem(url: url)
            videoPlayer.replaceCurrentItem(with: item)
            endOfPlaybackObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification,
                object: item,
                queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.videoPlayer.currentItem?.seek(to: .zero, completionHandler: nil)
                    self?.videoPlayer.play()
                }
            }
            // Setting a video clears any still preview to match ObjC behaviour.
            previewImage = nil
            isVideo = true
            videoPlayer.play()
        } else {
            videoPlayer.pause()
            isVideo = false
        }
        updateVideoFilters()
        setupPlaybackLayers()
        needsLayout = true
    }

    private func updateVideoFilters() {
        guard let lut else {
            lutVideoLayer.filters = nil
            return
        }
        do {
            let filter = try lut.coreImageFilter()
            lutVideoLayer.filters = [filter]
        } catch {
            lutVideoLayer.filters = nil
        }
    }

    private func updateMaskFrames(within bounds: CGRect? = nil) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let bounds = bounds ?? self.bounds
        let maskWidth = max(bounds.width * maskAmount, 0)

        processedContainerLayer.frame = CGRect(x: bounds.minX,
                                               y: bounds.minY,
                                               width: maskWidth,
                                               height: bounds.height)

        maskLayer.frame = CGRect(x: 0,
                                 y: 0,
                                 width: maskWidth,
                                 height: bounds.height)

        videoMaskLayer.frame = CGRect(x: 0,
                                      y: 0,
                                      width: maskWidth,
                                      height: bounds.height)

        let scale = window?.backingScaleFactor ?? 1
        let borderWidth = max(1.0 / scale, 1.0)
        borderLayer.frame = CGRect(x: max(maskWidth - borderWidth / 2, 0),
                                   y: 0,
                                   width: borderWidth,
                                   height: bounds.height)
        CATransaction.commit()
    }

    private func scheduleImageUpdate() {
        guard let image = previewImage else {
            originalLayer.contents = nil
            processedLayer.contents = nil
            cachedProcessedImage = nil
            return
        }

        originalLayer.contents = image

        if let cached = cachedProcessedImage {
            processedLayer.contents = cached
            return
        }

        guard let lut else {
            processedLayer.contents = image
            return
        }

        if let processed = lut.process(nsImage: image, renderPath: .coreImage)
            ?? lut.process(nsImage: image, renderPath: .direct) {
            cachedProcessedImage = processed
            processedLayer.contents = processed
        } else {
            processedLayer.contents = image
        }
        needsLayout = true
    }
}
#endif
