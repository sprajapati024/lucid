import SwiftUI
import MediaPlayer

struct VolumeSliderView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        volumeView.tintColor = UIColor(Color.lucidGreen)

        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                slider.minimumTrackTintColor = UIColor(Color.lucidGreen)
                slider.maximumTrackTintColor = UIColor(Color.lucidGray.opacity(0.4))
                slider.thumbTintColor = UIColor(Color.lucidWhite)
            }
        }

        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
