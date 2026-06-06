import UIKit

/// Панель настроек управления: инверсия обзора и чувствительность.
final class SettingsPanel: UIViewController {
    private let player: PlayerController

    init(player: PlayerController) {
        self.player = player
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.55)

        let card = UIView()
        card.backgroundColor = UIColor(white: 0.12, alpha: 0.97)
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        let title = label("Настройки", size: 20, weight: .bold)

        // Инверсия обзора
        let invertRow = UIStackView()
        invertRow.axis = .horizontal
        invertRow.distribution = .equalSpacing
        let invertLabel = label("Инверсия обзора (Y)", size: 16, weight: .regular)
        let invertSwitch = UISwitch()
        invertSwitch.isOn = player.invertY
        invertSwitch.addTarget(self, action: #selector(toggleInvert(_:)), for: .valueChanged)
        invertRow.addArrangedSubview(invertLabel)
        invertRow.addArrangedSubview(invertSwitch)

        // Чувствительность
        let sensLabel = label("Чувствительность обзора", size: 16, weight: .regular)
        let sens = UISlider()
        sens.minimumValue = 0.3
        sens.maximumValue = 2.5
        sens.value = player.lookSensitivity
        sens.addTarget(self, action: #selector(changeSens(_:)), for: .valueChanged)

        let close = UIButton(type: .system)
        close.setTitle("Готово", for: .normal)
        close.setTitleColor(.white, for: .normal)
        close.backgroundColor = UIColor(white: 0.25, alpha: 1)
        close.layer.cornerRadius = 8
        close.translatesAutoresizingMaskIntoConstraints = false
        close.heightAnchor.constraint(equalToConstant: 44).isActive = true
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, invertRow, sensLabel, sens, close])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 360),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight) -> UILabel {
        let l = UILabel()
        l.text = text
        l.textColor = .white
        l.font = .systemFont(ofSize: size, weight: weight)
        return l
    }

    @objc private func toggleInvert(_ s: UISwitch) { player.invertY = s.isOn }
    @objc private func changeSens(_ s: UISlider) { player.lookSensitivity = s.value }
    @objc private func closeTapped() { dismiss(animated: true) }
}
