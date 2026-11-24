
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@main
struct XBoosterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AudioEngine: ObservableObject {
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let eq = AVAudioUnitEQ(numberOfBands: 10)

    @Published var bass: Double = 12
    @Published var volume: Double = 0
    @Published var playing = false
    @Published var filename = "Выбери аудиофайл"

    var file: AVAudioFile?

    let frequencies: [Float] =
        [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    init() {
        for i in 0..<10 {
            let band = eq.bands[i]
            band.frequency = frequencies[i]
            band.gain = 0
            band.bypass = false
            band.filterType = i == 0 ? .lowShelf :
                (i == 9 ? .highShelf : .parametric)
        }

        engine.attach(player)
        engine.attach(eq)
        engine.connect(player, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
    }

    func update() {
        for i in 0..<10 {
            let boost = i == 0 ? bass * 0.75 :
                (i == 1 ? bass : (i == 2 ? bass * 0.45 : 0))
            eq.bands[i].gain = Float(min(18, boost))
        }
        engine.mainMixerNode.outputVolume =
            Float(pow(10, volume / 20))
    }

    func load(_ url: URL) {
        do {
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access { url.stopAccessingSecurityScopedResource() }
            }

            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(url.lastPathComponent)

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.copyItem(at: url, to: destination)
            file = try AVAudioFile(forReading: destination)
            filename = url.lastPathComponent
            player.stop()
            try engine.start()

            if let file {
                player.scheduleFile(file, at: nil)
            }
        } catch {
            filename = "Ошибка загрузки файла"
        }
    }

    func toggle() {
        guard file != nil else { return }
        if playing {
            player.pause()
            playing = false
        } else {
            do {
                if !engine.isRunning { try engine.start() }
                player.play()
                playing = true
            } catch {
                filename = "Ошибка воспроизведения"
            }
        }
    }
}

struct ContentView: View {
    @StateObject var audio = AudioEngine()
    @State private var picker = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color.purple.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Text("XBOOSTER")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)

                    Image(systemName: "waveform")
                        .font(.system(size: 65))
                        .foregroundStyle(.purple)

                    Text(audio.filename)
                        .foregroundStyle(.white)

                    Button("ВЫБРАТЬ МУЗЫКУ") {
                        picker = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button(audio.playing ? "ПАУЗА" : "ВОСПРОИЗВЕСТИ") {
                        audio.toggle()
                    }
                    .buttonStyle(.borderedProminent)

                    VStack(alignment: .leading, spacing: 15) {
                        Text("BASS BOOST: \(Int(audio.bass)) dB")
                            .foregroundStyle(.white)
                        Slider(value: $audio.bass, in: 0...18)
                            .tint(.purple)

                        Text("VOLUME: \(Int(audio.volume)) dB")
                            .foregroundStyle(.white)
                        Slider(value: $audio.volume, in: -12...6)
                            .tint(.pink)

                        Button("ПРИМЕНИТЬ") {
                            audio.update()
                        }
                        .foregroundStyle(.white)
                    }
                    .padding()
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(25)
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $picker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result,
               let url = urls.first {
                audio.load(url)
            }
        }
    }
}
