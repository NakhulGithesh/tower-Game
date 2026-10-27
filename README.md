# Castle Attack 🏰⚔️

A real-time 2-player tactical tower battle game modeled after Clash Royale. Players manage elixir, deploy defensive and offensive spells, and use drag-and-aim slingshot ballistics to destroy opponent fortresses.

Available as both a **Zero-Install Mobile Web Edition** and a **Native iOS (SpriteKit) Edition**.

---

## 🎮 Game Features

- **Mirrored Arena**: Both players view their own towers at the bottom and opponent towers at the top. Coordinate math is symmetrically mirrored in real time (`(x, y) ↔ (1-x, 1-y)`).
- **Procedural 2.5D Graphics**: Pure Canvas 2D isometric masonry, depth gradients, dynamic damage states (stress cracks, crumbled stones, rubble collapse), animated pennants, and living river caustics.
- **6 Tactical Cards**:
  | Card | Cost | Role | Effect |
  | :--- | :---: | :---: | :--- |
  | **Arrows** | 2 | Attack | Rapid volley splitting into 3 projectile paths |
  | **Shield** | 3 | Defense | Hexagonal crystal aegis absorbing all damage (5s) |
  | **Stones** | 4 | Attack | Heavy granite boulder (180 DMG) with screen shake |
  | **Repair** | 4 | Defense | Restores 150 HP over 5.0 seconds |
  | **Fireball** | 5 | Attack | Blazing inferno orb (100 DMG + 50 Burn over time) |
  | **Counter** | 5 | Hybrid | Spiked lightning aegis reflecting 120 incoming damage |
- **Tactical Rules**:
  - **Single-Card-Per-Tower Lockout**: Towers can only execute or hold one action/buff at a time.
  - **Elixir Economy**: Recharges 1 elixir every 1.5s (max 10).
- **Hardened Multiplayer Backend**:
  - Inbound rate limiting (30 msg/s) & 4KB payload cap.
  - Origin validation (CSWSH defense) & CSP security headers.
  - Cryptographic session UUIDs with a 10-second reconnect grace buffer for mobile network jitter.
  - Solo Bot AI mode fallback.

---

## 🚀 Quick Start

### 1. Mobile Web Edition (Zero-Install)

Runs on any browser (iOS Safari, Android Chrome, Desktop):

```bash
# Install dependencies
npm install

# Start the game server
npm start
```

- **Local play**: Open `http://localhost:8080` in two browser tabs (Tab 1 = Player A Blue, Tab 2 = Player B Red).
- **Mobile Wi-Fi play**: Connect phones on the same network to `http://<your-lan-ip>:8080`.
- **Global play**: Run `ngrok http 8080` to share a public HTTPS / WSS link.

---

### 2. Native iOS Edition

Built with Swift, SwiftUI, and SpriteKit:

```bash
# Generate Xcode project (requires XcodeGen)
xcodegen generate

# Open in Xcode
open CastleAttack.xcodeproj
```

---

## 🛠 Tech Stack

- **Frontend Web**: HTML5 Canvas (2D context, 60 FPS, Retina DPR scaling), Web Audio API (procedural synth), Touch Events API.
- **Backend Relay**: Node.js, Express, `ws` (WebSocket Server).
- **iOS App**: Swift 5.9+, SpriteKit, SwiftUI, URLSessionWebSocketTask.
- **Testing**: Deterministic packet verification suites & automated WebSocket integration tests.

---

## 📜 License

MIT License. Crafted for high-fidelity tactical mobile gaming.
