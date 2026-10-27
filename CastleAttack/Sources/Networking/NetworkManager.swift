import Foundation
import Combine

public enum NetworkRole: String, Codable {
    case none
    case host      // Player A (Royal Blue)
    case client    // Player B (Crimson Red)
    case localAI   // Solo / Single-screen testing
}

public enum ConnectionStatus: Equatable {
    case disconnected
    case connecting(serverURL: String)
    case connected(role: PlayerID, status: String)
    case error(message: String)
}

public final class NetworkManager: NSObject, ObservableObject {
    public static let shared = NetworkManager()
    
    // MARK: - Published Properties
    @Published public private(set) var status: ConnectionStatus = .disconnected
    @Published public private(set) var role: NetworkRole = .none
    @Published public private(set) var localPlayerID: PlayerID = .playerA
    @Published public private(set) var connectedPeerName: String? = nil
    @Published public private(set) var latencyMs: Int = 0
    @Published public var lastReceivedPacket: GamePacket? = nil
    @Published public private(set) var serverURLString: String = ""
    
    // MARK: - WebSocket Transport
    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    
    // Callbacks
    public var onPacketReceived: ((GamePacket) -> Void)?
    public var onMatchReady: (() -> Void)?
    public var onPeerDisconnected: (() -> Void)?
    
    public override init() {
        super.init()
    }
    
    // MARK: - Public Control API
    
    /// Connects to a remote or local WebSocket relay server (e.g. ngrok or LAN IP).
    public func connect(to urlString: String) {
        disconnect()
        
        var cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.starts(with: "https://") {
            cleanURL = "wss://" + cleanURL.dropFirst(8)
        } else if cleanURL.starts(with: "http://") {
            cleanURL = "ws://" + cleanURL.dropFirst(7)
        } else if !cleanURL.starts(with: "ws://") && !cleanURL.starts(with: "wss://") {
            cleanURL = "wss://" + cleanURL
        }
        
        guard let url = URL(string: cleanURL) else {
            self.status = .error(message: "Invalid Server URL")
            return
        }
        
        self.serverURLString = cleanURL
        self.status = .connecting(serverURL: cleanURL)
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        self.session = session
        self.webSocketTask = task
        task.resume()
        
        listenForMessages()
    }
    
    /// Enables standalone Local AI / Pass & Play test mode on a single device.
    public func startLocalAIMode() {
        disconnect()
        self.role = .localAI
        self.localPlayerID = .playerA
        self.connectedPeerName = "Local Arena Bot"
        self.status = .connected(role: .playerA, status: "Connected: Local Arena Bot")
    }
    
    /// Disconnects active sessions and resets network state.
    public func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        
        role = .none
        connectedPeerName = nil
        latencyMs = 0
        status = .disconnected
    }
    
    /// Transmits a game packet payload to the connected peer (or simulates in local mode).
    public func send(payload: PacketPayload) {
        let packet = GamePacket(sender: localPlayerID, payload: payload)
        
        if role == .localAI {
            DispatchQueue.main.async { [weak self] in
                self?.lastReceivedPacket = packet
                self?.onPacketReceived?(packet)
            }
            return
        }
        
        do {
            let data = try JSONEncoder().encode(packet)
            if let jsonString = String(data: data, encoding: .utf8) {
                webSocketTask?.send(.string(jsonString)) { error in
                    if let error = error {
                        print("[NetworkManager] WebSocket send error: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("[NetworkManager] Failed to encode packet: \(error.localizedDescription)")
        }
    }
    
    /// Sends a ping heartbeat to measure latency.
    public func ping() {
        guard role != .localAI else {
            self.latencyMs = 1
            return
        }
        
        let start = Date().timeIntervalSince1970
        webSocketTask?.sendPing { [weak self] error in
            if error == nil {
                let rtt = Date().timeIntervalSince1970 - start
                DispatchQueue.main.async {
                    self?.latencyMs = max(1, Int(rtt * 1000.0))
                }
            }
        }
        send(payload: .ping(clientTimestamp: start))
    }
    
    // MARK: - Message Loop & Handshake
    
    private func listenForMessages() {
        guard let task = webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingText(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleIncomingText(text)
                    }
                @unknown default:
                    break
                }
                self.listenForMessages()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    if self.status != .disconnected {
                        self.status = .error(message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private struct RelayControlMessage: Decodable {
        let type: String
        let role: String?
        let message: String?
    }
    
    private func handleIncomingText(_ text: String) {
        // 1. Check for relay control messages
        if let data = text.data(using: .utf8),
           let ctrl = try? JSONDecoder().decode(RelayControlMessage.self, from: data) {
            switch ctrl.type {
            case "assignRole":
                DispatchQueue.main.async {
                    if ctrl.role == "playerA" {
                        self.localPlayerID = .playerA
                        self.role = .host
                        self.connectedPeerName = "Waiting for Player B..."
                        self.status = .connected(role: .playerA, status: "Assigned: PLAYER A (BLUE) • Waiting for Player B...")
                    } else if ctrl.role == "playerB" {
                        self.localPlayerID = .playerB
                        self.role = .client
                        self.connectedPeerName = "Player A (Blue)"
                        self.status = .connected(role: .playerB, status: "Assigned: PLAYER B (RED) • Launching Battle!")
                    }
                }
                return
                
            case "matchReady":
                DispatchQueue.main.async {
                    if self.localPlayerID == .playerA {
                        self.connectedPeerName = "Player B (Red)"
                    } else {
                        self.connectedPeerName = "Player A (Blue)"
                    }
                    self.status = .connected(role: self.localPlayerID, status: "Assigned: \(self.localPlayerID == .playerA ? "PLAYER A (BLUE)" : "PLAYER B (RED)") • Launching Battle!")
                    self.onMatchReady?()
                }
                return
                
            case "peerDisconnected":
                DispatchQueue.main.async {
                    self.connectedPeerName = nil
                    if self.localPlayerID == .playerA {
                        self.status = .connected(role: .playerA, status: "Player B disconnected • Waiting for Player B...")
                    } else {
                        self.status = .error(message: "Host disconnected from arena.")
                    }
                    self.onPeerDisconnected?()
                }
                return
                
            case "error":
                DispatchQueue.main.async {
                    self.status = .error(message: ctrl.message ?? "Server error")
                }
                return
                
            default:
                break
            }
        }
        
        // 2. Decode GamePacket
        guard let data = text.data(using: .utf8) else { return }
        do {
            let packet = try JSONDecoder().decode(GamePacket.self, from: data)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                switch packet.payload {
                case .ping(let clientTimestamp):
                    self.send(payload: .pong(clientTimestamp: clientTimestamp))
                    return
                case .pong(let clientTimestamp):
                    let roundTrip = Date().timeIntervalSince1970 - clientTimestamp
                    self.latencyMs = max(1, Int(roundTrip * 1000.0 / 2.0))
                    return
                default:
                    break
                }
                
                self.lastReceivedPacket = packet
                self.onPacketReceived?(packet)
            }
        } catch {
            print("[NetworkManager] Decode packet error: \(error)")
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension NetworkManager: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[NetworkManager] WebSocket connection opened")
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.status != .disconnected {
                let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "Disconnected"
                self.status = .error(message: reasonStr)
            }
        }
    }
}
