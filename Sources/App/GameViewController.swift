import UIKit
import MetalKit
import simd

/// Экран игры: Metal-вью + сенсорное управление (зоны движения и обзора) + HUD инвентаря.
final class GameViewController: UIViewController {
    private var mtkView: MTKView!
    private var renderer: Renderer!
    private let game = GameState()

    // Отслеживание касаний: левая половина — движение, правая — обзор.
    private var moveTouch: UITouch?
    private var moveOrigin: CGPoint = .zero
    private var lookTouch: UITouch?
    private var lookLast: CGPoint = .zero

    private var inventoryBar: UIStackView!
    private var slotButtons: [UIButton] = []

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

        setupInventoryBar()
        setupButtons()
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
            b.layer.borderWidth = (i == game.inventory.selectedIndex) ? 3 : 1
            b.layer.borderColor = UIColor.white.cgColor
            b.tag = i
            b.addTarget(self, action: #selector(selectSlot(_:)), for: .touchUpInside)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 44).isActive = true
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
            slotButtons.append(b)
            inventoryBar.addArrangedSubview(b)
        }

        NSLayoutConstraint.activate([
            inventoryBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            inventoryBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                 constant: -12),
        ])
    }

    private func setupButtons() {
        let placeBtn = makeActionButton("Поставить")
        placeBtn.addTarget(self, action: #selector(placeTapped), for: .touchUpInside)
        let breakBtn = makeActionButton("Сломать")
        breakBtn.addTarget(self, action: #selector(breakTapped), for: .touchUpInside)
        let jumpBtn = makeActionButton("Прыжок")
        jumpBtn.addTarget(self, action: #selector(jumpTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [breakBtn, placeBtn, jumpBtn])
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

    private func makeActionButton(_ title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor(white: 0, alpha: 0.4)
        b.layer.cornerRadius = 8
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 110).isActive = true
        b.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return b
    }

    @objc private func selectSlot(_ sender: UIButton) {
        game.inventory.selectSlot(at: sender.tag)
        for (i, b) in slotButtons.enumerated() {
            b.layer.borderWidth = (i == game.inventory.selectedIndex) ? 3 : 1
        }
    }

    @objc private func placeTapped() { game.requestPlace() }
    @objc private func breakTapped() { game.requestBreak() }
    @objc private func jumpTapped() { game.jumpRequested = true }

    private func presentError(_ message: String) {
        let label = UILabel(frame: view.bounds)
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
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
                let dx = Float((p.x - moveOrigin.x) / 60)
                let dy = Float((moveOrigin.y - p.y) / 60)
                game.moveInput = SIMD2<Float>(max(-1, min(1, dx)), max(-1, min(1, dy)))
            } else if t == lookTouch {
                let d = SIMD2<Float>(Float(p.x - lookLast.x), Float(p.y - lookLast.y))
                game.lookDelta = d
                lookLast = p
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for t in touches {
            if t == moveTouch { moveTouch = nil; game.moveInput = .zero }
            if t == lookTouch { lookTouch = nil }
        }
    }

    override var prefersStatusBarHidden: Bool { true }
}
