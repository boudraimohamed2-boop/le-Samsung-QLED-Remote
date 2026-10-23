import SwiftUI
import Foundation

@main
struct SamsungQLEDRemoteApp: App {
    var body: some Scene {
        WindowGroup { RemoteView() }
    }
}

final class TVRemote: NSObject, ObservableObject, URLSessionDelegate {
    @Published var status = "Indique l’adresse IP de la télévision."
    @Published var connected = false
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var host = ""

    func connect(_ ip: String) {
        let ip = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ip.split(separator: ".").count == 4,
              ip.split(separator: ".").allSatisfy({ Int($0).map { (0...255).contains($0) } ?? false }) else {
            status = "Adresse IP incorrecte."
            return
        }
        disconnect()
        host = ip
        let name = Data("iPhone Remote".utf8).base64EncodedString()
        guard let url = URL(string: "wss://\\(ip):8002/api/v2/channels/samsung.remote.control?name=\\(name)") else { return }
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session?.webSocketTask(with: url)
        task?.resume()
        status = "Connexion… Accepte l’autorisation sur la TV."
        receive()
        // Test the connection via a ping; TV may still require on-screen authorization.
        task?.sendPing { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.status = "Connexion impossible : \\(error.localizedDescription)"
                } else {
                    self?.connected = true
                    self?.status = "Connecté. Autorise l’iPhone sur la TV si demandé."
                }
            }
        }
    }

    func send(_ key: String) {
        guard let task = task else { status = "Connecte d’abord la TV."; return }
        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": ["Cmd": "Click", "DataOfCmd": key,
                       "Option": "false", "TypeOfRemote": "SendRemoteKey"]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else { return }
        task.send(.string(string)) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async { self?.status = "Erreur : \\(error.localizedDescription)" }
            }
        }
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                DispatchQueue.main.async { self.connected = true; self.status = "Télécommande prête." }
                self.receive()
            case .failure(let error):
                DispatchQueue.main.async {
                    self.connected = false
                    self.status = "Déconnecté : \\(error.localizedDescription)"
                }
            }
        }
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        connected = false
    }

    // Samsung TVs commonly present self-signed TLS certificates.
    // Trust ONLY the user-entered local IP for this session.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == host,
              challenge.protectionSpace.port == 8002,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

struct RemoteView: View {
    @StateObject private var remote = TVRemote()
    @AppStorage("tvIP") private var ip = ""
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let keys: [(String, String)] = [
        ("⏻", "KEY_POWER"), ("Source", "KEY_SOURCE"), ("Muet", "KEY_MUTE"),
        ("Vol +", "KEY_VOLUP"), ("▲", "KEY_UP"), ("CH +", "KEY_CHUP"),
        ("◀", "KEY_LEFT"), ("OK", "KEY_ENTER"), ("▶", "KEY_RIGHT"),
        ("Vol −", "KEY_VOLDOWN"), ("▼", "KEY_DOWN"), ("CH −", "KEY_CHDOWN"),
        ("Retour", "KEY_RETURN"), ("Accueil", "KEY_HOME"), ("Menu", "KEY_MENU"),
        ("Lecture", "KEY_PLAY"), ("Pause", "KEY_PAUSE"), ("Info", "KEY_INFO")
    ]
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("📺 Samsung QLED").font(.title.bold())
                TextField("IP de la TV, ex. 192.168.1.20", text: $ip)
                    .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                Button("Connecter la TV") { remote.connect(ip) }
                    .buttonStyle(.borderedProminent)
                Text(remote.status).font(.footnote).multilineTextAlignment(.center)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(keys, id: \\.1) { label, key in
                        Button(label) { remote.send(key) }
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .background(key == "KEY_POWER" ? Color.red.opacity(0.8) : Color.blue.opacity(0.18))
                            .foregroundStyle(key == "KEY_POWER" ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                Text("L’iPhone et la TV doivent être sur le même Wi-Fi. L’allumage depuis une TV complètement éteinte dépend de son modèle et de ses réglages réseau.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
    }
}