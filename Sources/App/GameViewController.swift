import UIKit
import MetalKit
import simd

/// Экран игры: Metal-вью + сенсорное управление (зоны движения и обзора) + HUD.
final class GameViewController: UIViewController {
    private var mtkView: MTKView!
    private var renderer: Renderer!
    private let game = GameState()

    // Касания: левая половина — движение, правая — обзор.
    private var moveTouch: UITouch?
    private var moveOrigin: CGPoint = .zero
    private var lookTouch: UITouch?
    private var lookLast: CGPoint = .zero

    private var inventoryBar: UIStackView!
    private var slotButtons: [UIButton] = []
    private var slotBadges: [UILabel] = []

    // Удержание действий
    private var breakHeld = false
    private var placeHeld = false
    private var hudTimer: CADisplayLink?

    // Джойстик (визуальный)
    private var joystickBase: UIView!
    private var joystickKnob: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        mtkView = MTKView(frame: view.bounds)
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mtkView.preferredFramesPerSecond = 60
        view.addSubview(mtkView)

        guard let r = Renderer(mtkView: mtkView, game: game) else {
            presentError("Metal недоступен на этом устройстве")
            return
        }
        renderer = r
        mtkView.delegate = renderer
        mtkView.isMultipleTouchEnabled = true

        setupJoystick()
        setupInventoryBar()
        setupButtons()
        setupSettingsButton()

        hudTimer = CADisplayLink(target: self, selector: #selector(hudTick))
        hudTimer?.add(to: .main, forMode: .common)
    }

    // MARK: - HUD

    private func setupJoystick() {
        joystickBase = UIView()
        joystickBase.backgroundColor = UIColor(white: 1, alpha: 0.12)
        joystickBase.layer.cornerRadius = 60
        joystickBase.layer.borderWidth = 1
        joystickBase.layer.borderColor = UIColor(white: 1, alpha: 0.3).cgColor
        joystickBase.isUserInteractionEnabled = false
        joystickBase.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(joystickBase)

        joystickKnob = UIView()
        joystickKnob.backgroundColor = UIColor(white: 1, alpha: 0.35)
        joystickKnob.layer.cornerRadius = 26
        joystickKnob.isUserInteractionEnabled = false
        joystickKnob.translatesAutoresizingMaskIntoConstraints = false
        joystickBase.addSubview(joystickKnob)

        NSLayoutConstraint.activate([
            joystickBase.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            joystickBase.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            joystickBase.widthAnchor.constraint(equalToConstant: 120),
            joystickBase.heightAnchor.constraint(equalToConstant: 120),
            joystickKnob.centerXAnchor.constraint(equalTo: joystickBase.centerXAnchor),
            joystickKnob.centerYAnchor.constraint(equalTo: joystickBase.centerYAnchor),
            joystickKnob.widthAnchor.constraint(equalToConstant: 52),
            joystickKnob.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func setupInventoryBar() {
        inventoryBar = UIStackView()
        inventoryBar.axis = .horizontal
        inventoryBar.spacing = 8
        inventoryBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inventoryBar)

        for (i, slot) in game.inventory.slots.enumerated() {
            let b = UIButton(type: .system)
            let c = slot.type.color
            b.backgroundColor = UIColor(red: CGFloat(c.x), green: CGFloat(c.y),
                                        blue: CGFloat(c.z), alpha: 1)
            b.layer.cornerRadius = 6
            b.layer.borderWidth = (i == game.inventory.selectedIndex) ? 3 : 1
            b.layer.borderColor = UIColor.white.cgColor
            b.tag = i
            b.addTarget(self, action: #selector(selectSlot(_:)), for: .touchUpInside)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 46).isActive = true
            b.heightAnchor.constraint(equalToConstant: 46).isActive = true

            // Бейдж количества (Req 6.6/6.7)
            let badge = UILabel()
            badge.font = .systemFont(ofSize: 12, weight: .bold)
            badge.textColor = .white
            badge.textAlignment = .right
            badge.translatesAutoresizingMaskIntoConstraints = false
            b.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.trailingAnchor.constraint(equalTo: b.trailingAnchor, constant: -3),
                badge.bottomAnchor.constraint(equalTo: b.bottomAnchor, constant: -2),
            ])
            slotBadges.append(badge)

            slotButtons.append(b)
            inventoryBar.addArrangedSubview(b)
        }

        NSLayoutConstraint.activate([
            inventoryBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            inventoryBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                 constant: -12),
        ])
        refreshBadges()
    }

    private func setupButtons() {
        let breakBtn = makeActionButton("⛏ Сломать")
        addHold(to: breakBtn, down: #selector(breakDown), up: #selector(breakUp))
        let placeBtn = makeActionButton("⬛ Поставить")
        addHold(to: placeBtn, down: #selector(placeDown), up: #selector(placeUp))
        let jumpBtn = makeActionButton("⤒ Прыжок")
        jumpBtn.addTarget(self, action: #selector(jumpTapped), for: .touchUpInside)
        let sprintBtn = makeActionButton("» Бег")
        addHold(to: sprintBtn, down: #selector(sprintDown), up: #selector(sprintUp))

        let stack = UIStackView(arrangedSubviews: [breakBtn, placeBtn, jumpBtn, sprintBtn])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                                            constant: -16),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupSettingsButton() {
        let gear = makeActionButton("⚙")
        gear.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        gear.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gear)
        NSLayoutConstraint.activate([
            gear.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            gear.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            gear.widthAnchor.constraint(equalToConstant: 56),
        ])
    }

    private func addHold(to button: UIButton, down: Selector, up: Selector) {
        button.addTarget(self, action: down, for: .touchDown)
        button.addTarget(self, action: up, for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    private func makeActionButton(_ title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        b.backgroundColor = UIColor(white: 0, alpha: 0.4)
        b.layer.cornerRadius = 8
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 124).isActive = true
        b.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return b
    }

    // MARK: - Actions

    @objc private func selectSlot(_ sender: UIButton) {
        game.inventory.selectSlot(at: sender.tag)
        for (i, b) in slotButtons.enumerated() {
            b.layer.borderWidth = (i == game.inventory.selectedIndex) ? 3 : 1
        }
    }

    @objc private func breakDown() { breakHeld = true }
    @objc private func breakUp() { breakHeld = false }
    @objc private func placeDown() { placeHeld = true }
    @objc private func placeUp() { placeHeld = false }
    @objc private func sprintDown() { game.sprinting = true }
    @objc private func sprintUp() { game.sprinting = false }
    @objc private func jumpTapped() { game.jumpRequested = true }

    @objc private func hudTick() {
        if breakHeld { game.requestBreak() }
        if placeHeld { game.requestPlace() }
        refreshBadges()
    }

    private func refreshBadges() {
        for (i, slot) in game.inventory.slots.enumerated() {
            slotBadges[i].text = slot.count > 0 ? "\(slot.count)" : ""
        }
    }

    @objc private func openSettings() {
        let panel = SettingsPanel(player: game.player)
        panel.modalPresentationStyle = .overFullScreen
        panel.modalTransitionStyle = .crossDissolve
        present(panel, animated: true)
    }

    private func presentError(_ message: String) {
        let label = UILabel(frame: view.bounds)
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        view.addSubview(label)
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let mid = view.bounds.midX
        for t in touches {
            let p = t.location(in: view)
            if p.x < mid && moveTouch == nil {
                moveTouch = t; moveOrigin = p
            } else if p.x >= mid && lookTouch == nil {
                lookTouch = t; lookLast = p
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: view)
            if t == moveTouch {
                let raw = CGPoint(x: p.x - moveOrigin.x, y: p.y - moveOrigin.y)
                let dx = Float(max(-1, min(1, raw.x / 60)))
                let dy = Float(max(-1, min(1, -raw.y / 60)))
                game.moveInput = SIMD2<Float>(dx, dy)
                moveJoystickKnob(dx: raw.x, dy: raw.y)
            } else if t == lookTouch {
                let d = SIMD2<Float>(Float(p.x - lookLast.x), Float(p.y - lookLast.y))
                game.lookDelta = d
                lookLast = p
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }

    private func endTouches(_ touches: Set<UITouch>) {
        for t in touches {
            if t == moveTouch {
                moveTouch = nil
                game.moveInput = .zero
                resetJoystickKnob()
            }
            if t == lookTouch { lookTouch = nil }
        }
    }

    // MARK: - Joystick visuals

    private func moveJoystickKnob(dx: CGFloat, dy: CGFloat) {
        let r: CGFloat = 34
        let len = max(1, hypot(dx, dy))
        let clamped = min(len, r)
        let nx = dx / len * clamped
        let ny = dy / len * clamped
        joystickKnob.transform = CGAffineTransform(translationX: nx, y: ny)
    }
    private func resetJoystickKnob() {
        UIView.animate(withDuration: 0.1) { self.joystickKnob.transform = .identity }
    }

    override var prefersStatusBarHidden: Bool { true }
}
